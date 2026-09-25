import * as repository from '~/domain/author/infrastructure/repository'
import { portraitOf } from '~/domain/author/infrastructure/wikipedia'
import { AuthorBiography, Nationality } from '~/domain/author/primitives'
import { authorPrompt } from '~/domain/author/prompts'
import { AUTHOR_SCHEMA, type AuthorOutput } from '~/domain/author/schemas'
import type { Author, AuthorKey, AuthorSeries, AuthorWork } from '~/domain/author/types'
import type { BookLanguage } from '~/domain/book/types'
import { generate } from '~/domain/scan/gemini'
import type { AiStepUsage } from '~/domain/scan/types'
import { SeriesName, VolumeNumber } from '~/domain/series/primitives'
import type { Language } from '~/domain/shared/language'
import { AuthorName, BookTitle, Year } from '~/domain/shared/primitives'
import type { AuthorName as AuthorNameValue } from '~/domain/shared/types'
import { createLogger } from '~/system/logger'
import { isPresent, optionally } from '~/utils/input'

const logger = createLogger('author')

export namespace AuthorCommand {
  /** Record an author's catalogue. Nothing in it is per reader, so the write
   *  simply replaces whatever was there. */
  export const catalogue = (entry: Author): Promise<Author> => repository.save(entry)

  /** Ask the web about an author and store what it says: one grounded call for
   *  the facts and the bibliography, then Wikipedia for the portrait, on the page
   *  the model named.
   *
   *  Never throws: a page that could not be built shows the reader's own books.
   *  A failure or an answer with no bibliography is remembered as a miss rather
   *  than stored as a catalogue — one would mask the author as known — and no later
   *  opening asks again; the reader's refresh does. A catalogue already stored
   *  is left as it was. `usage` says what the call cost whenever it answered,
   *  stored or not. */
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

      const author = await catalogue({
        key,
        name: optionally(value.name, AuthorName) ?? name,
        nationality: optionally(value.nationality, Nationality),
        birthYear: optionally(value.birthYear, Year),
        deathYear: optionally(value.deathYear, Year),
        biography,
        portraitUrl: value.wikipediaTitle ? await portraitOf(value.wikipediaTitle) : undefined,
        series,
        books,
        cataloguedAt: new Date(),
      })
      return { author, usage }
    } catch (error) {
      logger.error('author catalogue generation failed', { error, key })
      await repository
        .saveMiss({ key, missedAt: new Date() })
        .catch((missError) => logger.warn('author miss not recorded', { error: missError, key }))
      return {}
    }
  }

  const parsedSeries = (raw: AuthorOutput['series'][number]): AuthorSeries | undefined => {
    const name = optionally(raw.name, SeriesName)
    if (!name) return undefined
    return {
      name,
      volumeCount: optionally(raw.volumeCount, VolumeNumber),
      firstVolumeTitle: optionally(raw.firstVolumeTitle, BookTitle),
    }
  }

  const parsedWork = (raw: AuthorOutput['books'][number]): AuthorWork | undefined => {
    const title = optionally(raw.title, BookTitle)
    if (!title) return undefined
    return { title, publishedIn: optionally(raw.publishedIn, Year) }
  }
}
