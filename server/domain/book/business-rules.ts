import type {
  Book,
  BookId,
  BookLanguage,
  BookView,
  LibrarySection,
  ReadingStatus,
  Subgenre,
  TaggedSubgenre,
} from '~/domain/book/types'
import { compareWithinSeries } from '~/domain/series/business-rules'
import type { UserId } from '~/domain/shared/types'
import { ObjectPath } from '~/system/object-store/primitives'
import type { ObjectPath as ObjectPathValue } from '~/system/object-store/types'

/** Arrange a library into the sections the list renders. A book that belongs to a
 *  saga sits under that saga's heading, ordered along the spine; everything else
 *  falls into a single trailing shelf.
 *
 *  A saga gets its own section even when the reader owns one volume of it. The
 *  alternative — grouping only from two volumes up — makes a book move between
 *  sections when an unrelated one is added, which reads as a bug.
 *
 *  Only the reader's own books appear. The catalogue never adds a row here: a
 *  volume the reader does not own is a proposal, and proposals live on the book
 *  and series screens, not in the library.
 *
 *  A saga held in two languages makes two sections, which is what the language
 *  is doing in the key. The volumes of a translation are different objects from
 *  the volumes of the original — other covers, other titles, read at other
 *  times — and one heading over both hid that. Books with no language recorded
 *  gather in a section of their own, which is honest: unknown is not French.
 *
 *  Sections come in three tiers, in the order the reader cares about them:
 *  what is being read, then what waits on the pile, then what is finished. A
 *  saga sits in the tier of its most active volume — one volume in progress
 *  lifts it to the top, whole — and a standalone book in its own status's
 *  tier, on a headless shelf trailing that tier's sagas: the leftovers, which
 *  must not bury the structure the reader came for. Within a tier the saga
 *  whose volume was most recently started, finished or put back on the pile
 *  comes first. Correcting a title or writing a note moves nothing: the list
 *  follows the reading, not the housekeeping. Inside a saga the spine order
 *  holds — a saga is read top to bottom, not by date. */
export const groupedBySeries = (books: readonly BookView[]): LibrarySection[] => {
  const bySeries = new Map<string, { section: LibrarySection['series']; books: SeriesBook[] }>()
  const standalone: BookView[] = []

  for (const book of books) {
    const membership = book.series
    if (!membership) {
      standalone.push(book)
      continue
    }
    const key = `${membership.id}\u0000${book.language ?? ''}`
    const bucket = bySeries.get(key)
    if (bucket) bucket.books.push({ book, membership })
    else
      bySeries.set(key, {
        section: { id: membership.id, name: membership.name, language: book.language },
        books: [{ book, membership }],
      })
  }

  const sagas: LibrarySection[] = [...bySeries.values()].map(({ section, books: entries }) => ({
    series: section,
    books: [...entries].sort(compareEntries).map((entry) => entry.book),
  }))

  const sections: LibrarySection[] = []
  for (const status of statusTiers) {
    sections.push(...sagas.filter((saga) => tierOf(saga) === status).sort(compareSections))
    const shelf = sortedByStatusChange(standalone.filter((book) => book.status === status))
    if (shelf.length === 0) continue
    // A tier with no saga of its own would leave two headless shelves back to
    // back, which read as one with a gap in it: they are drawn as one.
    const previous = sections.at(-1)
    if (previous && !previous.series) previous.books.push(...shelf)
    else sections.push({ books: shelf })
  }
  return sections
}

/** The tiers the library is read in, most active first. */
const statusTiers: readonly ReadingStatus[] = ['reading', 'to-read', 'read', 'dropped']

/** The tier of a saga: that of its most active volume. */
const tierOf = (section: LibrarySection): ReadingStatus =>
  statusTiers.find((status) => section.books.some((book) => book.status === status)) ?? 'read'

/** When the book last changed status, for the ordering above. A record from
 *  before the stamp existed answers with the date its status implies — finished
 *  for a read book, started for one in progress, added for one on the pile —
 *  which is when that status was in fact set. */
export const statusChangedAtOf = (
  book: Pick<Book, 'status' | 'addedAt' | 'startedAt' | 'finishedAt' | 'statusChangedAt'>,
): Date => {
  if (book.statusChangedAt) return book.statusChangedAt
  if (book.status === 'read') return book.finishedAt ?? book.addedAt
  if (book.status === 'reading') return book.startedAt ?? book.addedAt
  return book.addedAt
}

/** The stamp a status write leaves. Only a real move is stamped: choosing the
 *  status the book already has says nothing new, and must not lift its saga to
 *  the top of the library. */
export const statusStampAfterChange = (
  book: Pick<Book, 'status'>,
  next: ReadingStatus,
  now: Date,
): { statusChangedAt?: Date } => (book.status === next ? {} : { statusChangedAt: now })

/** A book paired with its membership, so the ordering below needs no non-null
 *  assertion: the pairing is what proves the book belongs to a saga. */
type SeriesBook = { book: BookView; membership: NonNullable<BookView['series']> }

const compareEntries = (left: SeriesBook, right: SeriesBook): number =>
  compareWithinSeries(
    { kind: left.membership.kind, number: left.membership.volume, title: left.book.title },
    { kind: right.membership.kind, number: right.membership.volume, title: right.book.title },
  )

// The saga with the most recent status change first; the name, then the
// language, break a tie so two sections never trade places between two reads
// of the same library.
const compareSections = (left: LibrarySection, right: LibrarySection): number => {
  const byStatusChange = lastStatusChangeOf(right) - lastStatusChangeOf(left)
  if (byStatusChange !== 0) return byStatusChange
  const byName = nameOf(left).localeCompare(nameOf(right))
  return byName !== 0 ? byName : languageOf(left).localeCompare(languageOf(right))
}

const lastStatusChangeOf = (section: LibrarySection): number =>
  Math.max(...section.books.map((book) => statusChangedAtOf(book).getTime()))

const nameOf = (section: LibrarySection): string => section.series?.name ?? ''

// An unrecorded language sorts last rather than first: a section that says
// nothing about its editions belongs under the ones that do.
const languageOf = (section: LibrarySection): string => section.series?.language ?? '\uffff'

const sortedByStatusChange = (books: readonly BookView[]): BookView[] =>
  [...books].sort(
    (left, right) =>
      statusChangedAtOf(right).getTime() - statusChangedAtOf(left).getTime() ||
      left.title.localeCompare(right.title),
  )

/** Which volumes of a saga the reader has finished — what decides whether the
 *  saga reads as complete. Only `read` counts: a volume in progress is not done. */
export const readVolumeNumbersOf = (books: readonly Book[]): Set<number> => {
  const numbers = new Set<number>()
  for (const book of books) {
    if (book.status !== 'read') continue
    const volume = book.series?.volume
    if (volume !== undefined) numbers.add(volume)
  }
  return numbers
}

/** The dates a status change implies. Reading dates are a consequence of moving
 *  the book, never something the reader types: asking for them would mean asking
 *  twice for the same fact.
 *
 *  Going back to `to-read` clears both dates. It is the reader saying the
 *  reading did not happen, and keeping a finish date on an unread book would
 *  surface it in reading statistics forever. */
export const datesAfterStatusChange = (
  book: Pick<Book, 'status' | 'startedAt' | 'finishedAt'>,
  next: ReadingStatus,
  now: Date,
): { startedAt?: Date; finishedAt?: Date } => {
  if (next === 'to-read') return { startedAt: undefined, finishedAt: undefined }
  if (next === 'reading' || next === 'dropped')
    return { startedAt: book.startedAt ?? now, finishedAt: undefined }
  // Finishing a book that was never marked as started still has a start: the
  // reader read it, they just never told the app. Stamping both keeps the
  // statistics honest rather than leaving a finished book with no beginning.
  return { startedAt: book.startedAt ?? now, finishedAt: book.finishedAt ?? now }
}

/** Rating a book means having read it. The app lets a reader rate from anywhere,
 *  and silently leaving such a book in `to-read` would be a lie the library then
 *  repeats in every filter. A dropped book keeps its status: one star is often
 *  exactly why it was dropped. */
export const statusAfterRating = (current: ReadingStatus): ReadingStatus =>
  current === 'dropped' ? 'dropped' : 'read'

/** Where a reader's cover images live in the bucket. Derived from the owner and
 *  the book, never chosen by a caller: a caller-supplied path is a traversal.
 *
 *  Keyed by owner first so an account deletion can erase every cover with one
 *  prefix sweep, rather than one delete per book it would have to enumerate
 *  after the Firestore records are already gone. */
export const coverPrefixOf = (userId: UserId): ObjectPathValue => ObjectPath(`covers/${userId}/`)

export const coverPathOf = (userId: UserId, bookId: BookId): ObjectPathValue =>
  ObjectPath(`${coverPrefixOf(userId)}${bookId}`)

/** Every subgenre the reader has used in `language`, the most used first and
 *  the alphabet breaking ties, folded on case so "Dark fantasy" and "dark
 *  fantasy" are one entry. What the edit form proposes as the reader types: a
 *  vocabulary drawn from their own shelf, in the language they type in, rather
 *  than from a list nobody agreed on. */
export const subgenresOf = (
  books: readonly Pick<Book, 'subgenres'>[],
  language: BookLanguage,
): Subgenre[] => {
  const counts = new Map<string, { subgenre: Subgenre; count: number }>()
  for (const book of books)
    for (const { label: subgenre } of book.subgenres.filter(
      (tagged) => tagged.language === language,
    )) {
      const key = subgenre.toLocaleLowerCase()
      const entry = counts.get(key)
      if (entry) entry.count += 1
      else counts.set(key, { subgenre, count: 1 })
    }
  return [...counts.values()]
    .sort((left, right) => right.count - left.count || left.subgenre.localeCompare(right.subgenre))
    .map((entry) => entry.subgenre)
}

/** Subgenres a reader typed, tagged with the language of their app: never
 *  translated, never read back by a model. */
export const taggedIn = (labels: readonly Subgenre[], language: BookLanguage): TaggedSubgenre[] =>
  labels.map((label) => ({ label, language }))

/** The subgenres of a book after the reader edited the list. A label the book
 *  already carried keeps the language it was written in — a scanned English
 *  "Grimdark" left in place stays English — and a new one keeps the language of
 *  the reader's app it was tagged with. Folded on case: retyping a label is not
 *  writing a new one. */
export const retaggedAfterEdit = (
  edited: readonly TaggedSubgenre[],
  current: readonly TaggedSubgenre[],
): TaggedSubgenre[] =>
  edited.map(({ label, language }) => ({
    label,
    language:
      current.find((tagged) => tagged.label.toLocaleLowerCase() === label.toLocaleLowerCase())
        ?.language ?? language,
  }))

/** The Library tab's order: newest first on the date that last moved each
 *  book, a flat list the app cuts into month sections wherever the month of
 *  that date changes, so the server alone decides what sits where. Sagas are
 *  not gathered: a volume sits on its own date, and the Series tab is where a
 *  saga is read whole. */
export const shelvedOf = <T extends Book>(books: readonly T[]): T[] =>
  [...books].sort(
    (left, right) =>
      shelfDateOf(right).getTime() - shelfDateOf(left).getTime() ||
      left.title.localeCompare(right.title),
  )

/** The date a book is shelved on, whatever its status: the day it was
 *  finished, else the day it was started, else the day it was added. A record
 *  whose reading dates were never stamped — an import, a book from before the
 *  dates existed — falls back to the day it was added. */
export const shelfDateOf = (book: Pick<Book, 'addedAt' | 'startedAt' | 'finishedAt'>): Date =>
  book.finishedAt ?? book.startedAt ?? book.addedAt

/** One page of the shelved list. The cursor is the last book of the previous
 *  page.
 *
 *  Cursor-less on the wire and in memory here: the list is derived from one
 *  memoized scan, so the page bounds the payload the app decodes and draws,
 *  not what Firestore reads. A cursor that names a book no longer there — it
 *  was deleted between two pages — restarts from the top, as Vinarium's does. */
export const shelfPageOf = <T extends Book>(
  books: readonly T[],
  limit: number,
  after?: BookId,
): { books: T[]; hasMore: boolean } => {
  const start = after ? books.findIndex((book) => book.id === after) + 1 : 0
  return { books: books.slice(start, start + limit), hasMore: start + limit < books.length }
}
