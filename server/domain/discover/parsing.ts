import { BookLanguageValue, Isbn13 } from '~/domain/book/primitives'
import { VolumeNumber } from '~/domain/series/primitives'
import type { Language } from '~/domain/shared/language'
import { BookTitle } from '~/domain/shared/primitives'
import { optionally } from '~/utils/input'
import { ReleaseDate } from './primitives'
import type { EditionOutput } from './schemas'
import type { TranslatedEdition } from './types'

/** One edition out of the model's answer, or nothing without a title, or in a
 *  language other than the one asked — a model that lists the original among
 *  the translations must not offer the reader the book they already read.
 *  Every other field is dropped on its own when it does not validate: a
 *  hallucinated ISBN must not cost the reader a real edition. */
export const editionFrom = (
  raw: EditionOutput,
  language: Language,
): TranslatedEdition | undefined => {
  const title = optionally(raw.title, BookTitle)
  if (!title) return undefined
  const stated = optionally(raw.language, BookLanguageValue)
  if (stated !== undefined && stated !== language) return undefined
  return {
    title,
    volume: optionally(raw.volume, VolumeNumber),
    format: raw.format === 'audiobook' ? 'audiobook' : 'book',
    date: optionally(raw.date, ReleaseDate),
    isbn13: optionally(raw.isbn13, Isbn13),
  }
}
