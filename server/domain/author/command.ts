import { chunk } from 'lodash-es'
import { keepingCorrections, withCorrection } from '~/domain/author/business-rules'
import * as favoriteRepository from '~/domain/author/infrastructure/favorite-repository'
import { openLibraryPortraitOf } from '~/domain/author/infrastructure/open-library'
import * as repository from '~/domain/author/infrastructure/repository'
import { wikidataPortraitOf } from '~/domain/author/infrastructure/wikidata'
import { portraitOf } from '~/domain/author/infrastructure/wikipedia'
import { AuthorBiography, Nationality } from '~/domain/author/primitives'
import { authorPrompt } from '~/domain/author/prompts'
import { AUTHOR_SCHEMA, type AuthorOutput } from '~/domain/author/schemas'
import type {
  Author,
  AuthorCorrection,
  AuthorKey,
  AuthorSeries,
  AuthorWork,
} from '~/domain/author/types'
import type { BookLanguage, CoverUrl } from '~/domain/book/types'
import { generate } from '~/domain/scan/gemini'
import { openLibraryCoverByTitle } from '~/domain/scan/open-library'
import type { AiStepUsage } from '~/domain/scan/types'
import { SeriesName, VolumeNumber } from '~/domain/series/primitives'
import type { Language } from '~/domain/shared/language'
import { AuthorName, BookTitle, Year } from '~/domain/shared/primitives'
import type { AuthorName as AuthorNameValue, UserId } from '~/domain/shared/types'
import { createLogger } from '~/system/logger'
import { isTimeout } from '~/utils/fetch'
import { isPresent, optionally } from '~/utils/input'

const logger = createLogger('author')

/** An author's photograph: Wikipedia's, whose page is the one the model
 *  named, else Wikidata's, which knows which namesake is the writer and finds
 *  the portrait another language's page shows, else Open Library's, which
 *  keeps writers no Wikimedia project has a photo of. The three are asked at
 *  once, so a miss costs one timeout rather than three in a row. */
const faceOf = async (name: AuthorNameValue, pageTitle?: string) => {
  const [wikipedia, wikidata, openLibrary] = await Promise.all([
    portraitOf(name, pageTitle),
    wikidataPortraitOf(name),
    openLibraryPortraitOf(name),
  ])
  return wikipedia ?? wikidata ?? openLibrary
}

export namespace AuthorCommand {
  /** Heart an author, or take the heart back: the reader's own, whatever
   *  their books say. Answers what is now true. */
  export const setFavorite = async (
    userId: UserId,
    key: AuthorKey,
    favorite: boolean,
    at: Date = new Date(),
  ): Promise<boolean> => {
    if (favorite) await favoriteRepository.save({ userId, authorKey: key, favoritedAt: at })
    else await favoriteRepository.remove(userId, key)
    return favorite
  }

  export const deleteFavoritesOf = (userId: UserId): Promise<void> =>
    favoriteRepository.removeAllByUser(userId)

  /** Record an author's catalogue. Nothing in it is per reader, so the write
   *  simply replaces whatever was there. */
  export const catalogue = (entry: Author): Promise<Author> => repository.save(entry)

  /** Write a reader's correction into an author's catalogue, for every reader,
   *  the fields it names marked so that no later catalogue call or portrait
   *  lookup writes over them. An author nobody could describe gets a
   *  catalogue holding the correction alone: the model is never asked about a
   *  miss again, so nothing is lost. */
  export const correct = (
    current: Author | null,
    key: AuthorKey,
    name: AuthorNameValue,
    correction: AuthorCorrection,
    at: Date = new Date(),
  ): Promise<Author> =>
    repository.save(
      withCorrection(current ?? { key, name, series: [], books: [], cataloguedAt: at }, correction),
    )

  /** Ask again for the face of an author catalogued without one, by their
   *  name, and store what it says — the portrait, or when it was sought.
   *  Never throws: the page keeps the catalogue it had. */
  export const seekPortrait = async (author: Author): Promise<Author> => {
    if (author.corrected?.includes('portraitUrl')) return author
    const portraitUrl = await faceOf(author.name)
    try {
      return await catalogue(
        portraitUrl
          ? { ...author, portraitUrl, portraitSoughtAt: undefined }
          : { ...author, portraitSoughtAt: new Date() },
      )
    } catch (error) {
      logger.warn('author portrait not recorded', { error, key: author.key })
      return portraitUrl ? { ...author, portraitUrl } : author
    }
  }

  /** Ask the web about an author and store what it says: one grounded call for
   *  the facts and the bibliography, then Wikipedia for the portrait, on the page
   *  the model named, and Open Library when Wikipedia has none.
   *
   *  Never throws: a page that could not be built shows the reader's own books.
   *  A failure or an answer with no bibliography is remembered as a miss rather
   *  than stored as a catalogue — one would mask the author as known — and no later
   *  opening asks again; the reader's refresh does. A catalogue already stored
   *  is left as it was. `usage` says what the call cost whenever it answered,
   *  stored or not.
   *
   *  A refresh whose portrait lookup comes back empty keeps the portrait the
   *  stored catalogue had: Wikipedia missing a page today must not take the
   *  author's face off a page that showed it. */
  export const catalogueFromWeb = async (
    key: AuthorKey,
    name: AuthorNameValue,
    language: Language,
    editionLanguage?: BookLanguage,
  ): Promise<{ author?: Author; usage?: AiStepUsage }> => {
    try {
      const { value, usage } = await generate<AuthorOutput>({
        step: 'author',
        parts: [{ text: authorPrompt(name, language, editionLanguage) }],
        responseSchema: AUTHOR_SCHEMA,
        grounded: true,
      })
      const biography = optionally(value.biography, AuthorBiography)
      const series = value.series.map(parsedSeries).filter(isPresent)
      const books = value.books.map(parsedWork).filter(isPresent)
      // A biography alone is no page: the bibliography is what the reader came
      // for, and a catalogue stored without one would never be asked again.
      if (series.length === 0 && books.length === 0) {
        await repository.saveMiss({ key, missedAt: new Date() })
        return { usage }
      }

      const signedName = optionally(value.name, AuthorName) ?? name
      const openLibrary: CoverLookup = { author: signedName, unreachable: false }
      const [foundPortrait, coveredSeries, coveredBooks] = await Promise.all([
        faceOf(signedName, value.wikipediaTitle ?? undefined),
        withCovers(series, openLibrary),
        withCovers(books, openLibrary),
      ])
      const previous = await repository.findByKey(key)
      const portraitUrl = foundPortrait ?? previous?.portraitUrl
      const built: Author = {
        key,
        name: signedName,
        nationality: optionally(value.nationality, Nationality),
        birthYear: optionally(value.birthYear, Year),
        deathYear: optionally(value.deathYear, Year),
        biography,
        portraitUrl,
        portraitSoughtAt: portraitUrl ? undefined : new Date(),
        series: coveredSeries,
        books: coveredBooks,
        cataloguedAt: new Date(),
      }
      const author = await catalogue(keepingCorrections(built, previous))
      return { author, usage }
    } catch (error) {
      logger.error('author catalogue generation failed', { error, key })
      await repository
        .saveMiss({ key, missedAt: new Date() })
        .catch((missError) => logger.warn('author miss not recorded', { error: missError, key }))
      return {}
    }
  }

  /** A saga or a book as the model listed it, with the title Open Library
   *  knows the work by — kept for the cover lookup, never stored. */
  type Listed<T> = { entry: T; originalTitle?: string }

  const parsedSeries = (raw: AuthorOutput['series'][number]): Listed<AuthorSeries> | undefined => {
    const name = optionally(raw.name, SeriesName)
    if (!name) return undefined
    const firstVolumeTitle = optionally(raw.firstVolumeTitle, BookTitle)
    return {
      entry: { name, volumeCount: optionally(raw.volumeCount, VolumeNumber), firstVolumeTitle },
      originalTitle: raw.firstVolumeOriginalTitle?.trim() || firstVolumeTitle,
    }
  }

  const parsedWork = (raw: AuthorOutput['books'][number]): Listed<AuthorWork> | undefined => {
    const title = optionally(raw.title, BookTitle)
    if (!title) return undefined
    return {
      entry: { title, publishedIn: optionally(raw.publishedIn, Year) },
      originalTitle: raw.originalTitle?.trim() || title,
    }
  }

  /** Open Library throttles a burst: a prolific author's forty books are asked
   *  for a few at a time rather than all at once. */
  const COVER_LOOKUPS_AT_ONCE = 5

  /** One catalogue's cover lookups, shared by its sagas and its books. */
  type CoverLookup = { author: AuthorNameValue; unreachable: boolean }

  /** Each entry with its cover, looked up by the original title — once, when
   *  the catalogue is built, so no opening waits on Open Library. An entry
   *  Open Library has no cover for keeps the placeholder.
   *
   *  The first failed search ends them all. Open Library fails in bursts — ten
   *  searches timing out in the same second on September 30th 2026 — and the
   *  scan waits on this: every further slice would cost the reader three more
   *  seconds for covers that will not come. The entries left keep the
   *  placeholder, and the burst is one warning rather than one per book. */
  const withCovers = async <T extends { coverUrl?: CoverUrl }>(
    listed: readonly Listed<T>[],
    lookup: CoverLookup,
  ): Promise<T[]> => {
    const covered: T[] = []
    for (const slice of chunk(listed, COVER_LOOKUPS_AT_ONCE)) {
      const found = lookup.unreachable
        ? []
        : await Promise.allSettled(
            slice.map(({ originalTitle }) =>
              originalTitle ? openLibraryCoverByTitle(originalTitle, lookup.author) : undefined,
            ),
          )
      const failure = found.find((result) => result.status === 'rejected')
      if (failure && !lookup.unreachable) {
        lookup.unreachable = true
        // Running out of time is the cutoff doing its job, not a failure to look into.
        if (isTimeout(failure.reason))
          logger.info('Open Library title search timed out', { author: lookup.author })
        else
          logger.warn('Open Library title search failed', {
            error: failure.reason,
            author: lookup.author,
          })
      }
      covered.push(
        ...slice.map(({ entry }, index) => {
          const result = found[index]
          const coverUrl = result?.status === 'fulfilled' ? result.value : undefined
          return coverUrl ? { ...entry, coverUrl } : entry
        }),
      )
    }
    return covered
  }
}
