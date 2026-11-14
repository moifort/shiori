import type { EditionOutput } from '~/domain/awaited-edition/schemas'
import type { FoundEdition } from '~/domain/awaited-edition/types'
import { Isbn13 } from '~/domain/book/primitives'
import { ReleaseDate } from '~/domain/series/primitives'
import { AudibleAsin, BookTitle } from '~/domain/shared/primitives'
import { optionally } from '~/utils/input'

/** The edition of the model's answer, or nothing when it found none or gave it
 *  no title. Every other field is dropped on its own when it does not
 *  validate: a hallucinated ISBN must not cost the reader a real edition. */
export const editionFrom = (raw: EditionOutput): FoundEdition | undefined => {
  const title = optionally(raw.title, BookTitle)
  if (!raw.found || !title) return undefined
  return {
    title,
    date: optionally(raw.date, ReleaseDate),
    isbn13: optionally(raw.isbn13, Isbn13),
    asin: optionally(raw.asin, AudibleAsin),
  }
}
