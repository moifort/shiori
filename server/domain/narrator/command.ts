import { portraitOf } from '~/domain/author/infrastructure/wikipedia'
import { Nationality } from '~/domain/author/primitives'
import type { NarratorName } from '~/domain/book/types'
import * as favoriteRepository from '~/domain/narrator/infrastructure/favorite-repository'
import * as repository from '~/domain/narrator/infrastructure/repository'
import { NarratorBiography } from '~/domain/narrator/primitives'
import { narratorPrompt } from '~/domain/narrator/prompts'
import { NARRATOR_SCHEMA, type NarratorOutput } from '~/domain/narrator/schemas'
import type { Narrator, NarratorKey } from '~/domain/narrator/types'
import { generate } from '~/domain/scan/gemini'
import type { AiStepUsage } from '~/domain/scan/types'
import type { Language } from '~/domain/shared/language'
import { Year } from '~/domain/shared/primitives'
import type { AuthorName, UserId } from '~/domain/shared/types'
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

  /** Ask Wikipedia again for the face of a narrator described without one, by
   *  their name, and store what it says — the portrait, or when it was sought.
   *  Free: no model call. Never throws: the page draws the initials. */
  export const seekPortrait = async (known: Narrator, at: Date = new Date()): Promise<Narrator> => {
    const portraitUrl = await faceOf(known.name)
    const entry: Narrator = portraitUrl
      ? { ...known, portraitUrl, portraitSoughtAt: undefined }
      : { ...known, portraitSoughtAt: at }
    try {
      return await repository.save(entry)
    } catch (error) {
      logger.warn('narrator portrait not recorded', { error, key: known.key })
      return entry
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
    known: Narrator | null,
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
      const portraitUrl = foundPortrait ?? known?.portraitUrl
      const face = portraitUrl ? { portraitUrl } : { portraitSoughtAt: at }
      const narrator: Narrator = biography
        ? {
            key,
            name: known?.name ?? name,
            nationality: optionally(value.nationality, Nationality),
            birthYear: optionally(value.birthYear, Year),
            deathYear: optionally(value.deathYear, Year),
            biography,
            ...face,
            cataloguedAt: at,
          }
        : { key, name: known?.name ?? name, ...face, missedAt: at }
      return { narrator: await save(narrator), usage }
    } catch (error) {
      logger.error('narrator catalogue generation failed', { error, key })
      const portraitUrl = known?.portraitUrl ?? (await faceOf(name))
      const missed: Narrator = {
        ...(known ?? { key, name }),
        ...(portraitUrl ? { portraitUrl, portraitSoughtAt: undefined } : { portraitSoughtAt: at }),
        missedAt: at,
      }
      return { narrator: await save(missed) }
    }
  }

  /** Stores the entry, logging a failed write rather than failing the page:
   *  the reader still sees what was found. */
  const save = async (entry: Narrator): Promise<Narrator> => {
    try {
      return await repository.save(entry)
    } catch (error) {
      logger.warn('narrator catalogue not recorded', { error, key: entry.key })
      return entry
    }
  }
}
