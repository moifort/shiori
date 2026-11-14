import { keepingCorrectionsOf, withCorrectionOf } from '~/domain/author/business-rules'
import { portraitOf } from '~/domain/author/infrastructure/wikipedia'
import { Nationality } from '~/domain/author/primitives'
import type { NarratorName } from '~/domain/book/types'
import * as favoriteRepository from '~/domain/narrator/infrastructure/favorite-repository'
import * as repository from '~/domain/narrator/infrastructure/repository'
import { NarratorBiography } from '~/domain/narrator/primitives'
import { narratorPrompt } from '~/domain/narrator/prompts'
import { NARRATOR_SCHEMA, type NarratorOutput } from '~/domain/narrator/schemas'
import {
  NARRATOR_CORRECTABLE_FIELDS,
  type Narrator,
  type NarratorCorrectableField,
  type NarratorCorrection,
  type NarratorKey,
} from '~/domain/narrator/types'
import type { Language } from '~/domain/shared/language'
import { Year } from '~/domain/shared/primitives'
import type { AuthorName, UserId } from '~/domain/shared/types'
import { generate } from '~/system/gemini'
import type { AiStepUsage } from '~/system/gemini/usage'
import { createLogger } from '~/system/logger'
import { optionally } from '~/utils/input'

const logger = createLogger('narrator')

/** A narrator's face on Wikipedia: the page the model named, else their name.
 *  A narrator's name is no author's, but Wikipedia is asked by name alone.
 *  Wikidata and Open Library, which the author's face also asks, know writers
 *  only. */
const faceOf = (name: NarratorName, pageTitle?: string) =>
  portraitOf(name as string as AuthorName, pageTitle)

export namespace NarratorCommand {
  /** Heart a narrator, or take the heart back: the reader's own. Answers what
   *  is now true. */
  export const setFavorite = async (
    userId: UserId,
    key: NarratorKey,
    favorite: boolean,
    at: Date = new Date(),
  ): Promise<boolean> => {
    if (favorite) await favoriteRepository.save({ userId, narratorKey: key, favoritedAt: at })
    else await favoriteRepository.remove(userId, key)
    return favorite
  }

  export const deleteFavoritesOf = (userId: UserId): Promise<void> =>
    favoriteRepository.removeAllByUser(userId)

  /** Write a reader's correction into a narrator's entry, for every reader,
   *  the fields it names marked so that no later catalogue call or portrait
   *  lookup writes over them. A narrator nobody described gets an entry
   *  holding the correction alone, and the model is not asked about them. */
  export const correct = (
    current: Narrator | undefined,
    key: NarratorKey,
    name: NarratorName,
    correction: NarratorCorrection,
  ): Promise<Narrator> =>
    revised(key, (stored) =>
      withCorrectionOf(NARRATOR_CORRECTABLE_FIELDS, stored ?? current ?? { key, name }, correction),
    )

  /** Ask Wikipedia again for the face of a narrator described without one, by
   *  their name, and store what it says — the portrait, or when it was sought.
   *  Free: no model call. Never throws: the page draws the initials. */
  export const seekPortrait = async (known: Narrator, at: Date = new Date()): Promise<Narrator> => {
    if (known.corrected?.includes('portraitUrl')) return known
    const portraitUrl = await faceOf(known.name)
    const withFace = (narrator: Narrator): Narrator =>
      portraitUrl
        ? { ...narrator, portraitUrl, portraitSoughtAt: undefined }
        : { ...narrator, portraitSoughtAt: at }
    try {
      // On the entry as it stands: a reader may have corrected it meanwhile.
      return await revised(known.key, (stored) => {
        const current = stored ?? known
        return current.corrected?.includes('portraitUrl') ? undefined : withFace(current)
      })
    } catch (error) {
      logger.warn('narrator portrait not recorded', { error, key: known.key })
      return withFace(known)
    }
  }

  /** Ask the web who a narrator is and store what it says: one grounded call
   *  for the facts and the biography, then Wikipedia for the portrait, on the
   *  page the model named.
   *
   *  Never throws: a page that could not be described shows the reader's
   *  recordings. A failure or an answer with no biography is remembered as a
   *  miss, with whatever face Wikipedia gives the name, and no opening asks
   *  the model again for a month. `usage` says what the call cost whenever it
   *  answered, stored or not. A portrait found before is kept when this
   *  lookup comes back empty. */
  export const catalogueFromWeb = async (
    known: Narrator | undefined,
    key: NarratorKey,
    name: NarratorName,
    language: Language,
    at: Date = new Date(),
  ): Promise<{ narrator: Narrator; usage?: AiStepUsage }> => {
    try {
      const { value, usage } = await generate<NarratorOutput>({
        step: 'narrator',
        parts: [{ text: narratorPrompt(name, language) }],
        responseSchema: NARRATOR_SCHEMA,
        grounded: true,
      })
      const biography = optionally(value.biography, NarratorBiography)
      const foundPortrait = await faceOf(name, value.wikipediaTitle ?? undefined)
      const narratorFrom = (previous: Narrator | undefined): Narrator => {
        const portraitUrl = foundPortrait ?? previous?.portraitUrl
        const face = portraitUrl ? { portraitUrl } : { portraitSoughtAt: at }
        return biography
          ? {
              key,
              name: previous?.name ?? name,
              nationality: optionally(value.nationality, Nationality),
              birthYear: optionally(value.birthYear, Year),
              deathYear: optionally(value.deathYear, Year),
              biography,
              ...face,
              cataloguedAt: at,
            }
          : { key, name: previous?.name ?? name, ...face, missedAt: at }
      }
      return { narrator: await save(key, narratorFrom, known), usage }
    } catch (error) {
      logger.error('narrator catalogue generation failed', { error, key })
      const portraitUrl = known?.portraitUrl ?? (await faceOf(name))
      const missedFrom = (previous: Narrator | undefined): Narrator => {
        const face = previous?.portraitUrl ?? portraitUrl
        return {
          ...(previous ?? { key, name }),
          ...(face ? { portraitUrl: face, portraitSoughtAt: undefined } : { portraitSoughtAt: at }),
          missedAt: at,
        }
      }
      return { narrator: await save(key, missedFrom, known) }
    }
  }

  /** Stores the entry built on the one stored, with what readers corrected on
   *  it, logging a failed write rather than failing the page: the reader
   *  still sees what was found. */
  const save = async (
    key: NarratorKey,
    entryFrom: (previous: Narrator | undefined) => Narrator,
    known: Narrator | undefined,
  ): Promise<Narrator> => {
    try {
      return await revised(key, (previous) =>
        keepingCorrectionsOf<NarratorCorrectableField, Narrator>(entryFrom(previous), previous),
      )
    } catch (error) {
      logger.warn('narrator catalogue not recorded', { error, key })
      return keepingCorrectionsOf<NarratorCorrectableField, Narrator>(entryFrom(known), known)
    }
  }
}

/** The entry as `revise` left it, written on the one stored. */
const revised = async (
  key: NarratorKey,
  revise: (current: Narrator | undefined) => Narrator | undefined,
): Promise<Narrator> => {
  const narrator = await repository.revise(key, revise)
  if (!narrator) throw new Error('a narrator just written is missing')
  return narrator
}
