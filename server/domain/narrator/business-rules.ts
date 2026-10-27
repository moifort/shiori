import { PORTRAIT_RETRY_DAYS, shelvedPeopleOf } from '~/domain/author/business-rules'
import type { BookFormat, NarratorName } from '~/domain/book/types'
import { narratorKeyOf } from '~/domain/narrator/primitives'
import type { Narrator, NarratorKey, ShelvedNarrator } from '~/domain/narrator/types'
import type { SagaKey } from '~/domain/series/types'
import { Count } from '~/domain/shared/primitives'

type NarratedBook = {
  title: string
  format: BookFormat
  narrators?: NarratorName[]
  series?: { saga: SagaKey }
  rating?: number
  favorite?: boolean
  addedAt: Date
  startedAt?: Date
  finishedAt?: Date
}

type SagaOpinion = { seriesId: SagaKey; rating?: number; favorite?: boolean }

/** Every narrator the library holds a recording of, with what the reader made
 *  of those recordings and of the sagas heard they belong to — counted as an
 *  author's are. Only recordings name one: a narrator left on a book that is
 *  no longer an audiobook reads nothing. */
export const shelvedNarratorsOf = <Book extends NarratedBook>(
  books: readonly Book[],
  opinions: readonly SagaOpinion[],
): ShelvedNarrator<Book>[] =>
  shelvedPeopleOf(
    books.filter((book) => book.format === 'audiobook'),
    opinions,
    (book) => book.narrators ?? [],
    narratorKeyOf,
  )

/** A narrator the reader holds nothing of, as a friend's recording names one:
 *  the name, and nothing of the reader's. Null unless the name folds into the
 *  key, so a page is never drawn for somebody else. */
export const unshelvedNarratorOf = <Book>(
  key: NarratorKey,
  name: NarratorName,
  now: Date,
): ShelvedNarrator<Book> | null =>
  narratorKeyOf(name) === key
    ? { key, name, books: [], seriesIds: [], shelvedAt: now, favoriteCount: Count(0) }
    : null

/** Whether the model is to be asked who a narrator is: never once described
 *  or corrected by a reader, and not a month after it failed on them — every
 *  opening would otherwise wait on the same grounded call. */
export const isWorthDescribing = (known: Narrator | null, now: Date): boolean => {
  if (!known) return true
  if (known.cataloguedAt || known.corrected?.length) return false
  if (!known.missedAt) return true
  return now.getTime() - known.missedAt.getTime() >= PORTRAIT_RETRY_DAYS * 86_400_000
}

/** Whether the page has anything to say of who the narrator is: described by
 *  the model, or by a reader's hand. */
export const isDescribed = (known: Narrator | null): known is Narrator =>
  Boolean(known?.cataloguedAt || known?.corrected?.length)
