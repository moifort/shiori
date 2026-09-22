import type {
  Book,
  BookId,
  BookLanguage,
  BookView,
  LibrarySection,
  ReadingStatus,
  Recommendation,
  SeriesMembership,
  SeriesPlacement,
  ShelfVocabulary,
  StarRating,
  Subgenre,
  TaggedSubgenre,
} from '~/domain/book/types'
import { compareWithinSeries } from '~/domain/series/business-rules'
import { seriesKeyOf } from '~/domain/series/primitives'
import type { SeriesId, SeriesName } from '~/domain/series/types'
import type { AuthorName, UserId } from '~/domain/shared/types'
import { ObjectPath } from '~/system/object-store/primitives'
import type { ObjectPath as ObjectPathValue } from '~/system/object-store/types'
import { slugify } from '~/utils/slug'

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

/** How far into a recording the reader is, as a whole percentage of its
 *  running time, rounded down so a title only reads 100 once the player got
 *  there. Undefined without a running time or a position — a printed book, or
 *  a recording the player never opened. */
export const listeningProgressOf = (
  book: Pick<Book, 'durationMinutes' | 'listenedMinutes'>,
): number | undefined => {
  if (book.durationMinutes === undefined || book.listenedMinutes === undefined) return undefined
  return Math.min(100, Math.floor((book.listenedMinutes / book.durationMinutes) * 100))
}

/** The stars a book shows: its own, else the rating of its saga. A saga rated
 *  as a whole rates each volume the reader left unrated, and a rating given to
 *  the book itself always wins. `seriesRatings` is the reader's saga ratings,
 *  keyed by saga. */
export const shownRatingOf = (
  book: Pick<Book, 'rating' | 'series'>,
  seriesRatings: ReadonlyMap<SeriesId, StarRating>,
): StarRating | undefined =>
  book.rating ?? (book.series ? seriesRatings.get(book.series.id) : undefined)

/** The reader's saga ratings, keyed by saga, from their opinions. */
export const seriesRatingsOf = (
  opinions: readonly { seriesId: SeriesId; rating?: StarRating }[],
): Map<SeriesId, StarRating> =>
  new Map(
    opinions.flatMap((opinion) =>
      opinion.rating === undefined ? [] : [[opinion.seriesId, opinion.rating] as const],
    ),
  )

/** The "Rated" view of the library: every book that shows stars, the best
 *  first, and within one band of stars in the order of the shelf. A volume
 *  rated through its saga ranks on that rating, since that is what it shows. */
export const ratedShelfOf = <T extends Book>(
  books: readonly T[],
  seriesRatings: ReadonlyMap<SeriesId, StarRating>,
): T[] =>
  shelvedOf(books)
    .map((book) => ({ book, rating: shownRatingOf(book, seriesRatings) }))
    .filter((entry): entry is { book: T; rating: StarRating } => entry.rating !== undefined)
    .sort((left, right) => right.rating - left.rating)
    .map((entry) => entry.book)

/** Which main volumes of a saga the reader has finished — what decides whether
 *  the saga reads as complete. Only `read` counts: a volume in progress is not
 *  done. Only the main spine counts: a related work carries its own numbering,
 *  and novella 2 read is not tome 2 read. */
export const readVolumeNumbersOf = (books: readonly Book[]): Set<number> => {
  const numbers = new Set<number>()
  for (const book of books) {
    if (book.status !== 'read' || book.series?.kind !== 'main') continue
    const volume = book.series.volume
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
/** The recommendation to store: the one given, unless it says nothing. A
 *  reader who empties both the name and the words has taken the recommendation
 *  back, and an empty map on the record would draw a blank section. */
export const storedRecommendation = (
  recommendation: Recommendation | undefined,
): Recommendation | undefined =>
  recommendation?.recommenderName || recommendation?.comment
    ? {
        ...(recommendation.recommenderName
          ? { recommenderName: recommendation.recommenderName }
          : {}),
        ...(recommendation.comment ? { comment: recommendation.comment } : {}),
      }
    : undefined

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

/** Every saga the reader holds a volume of, named once and alphabetically,
 *  folded on case: a saga held in two languages, or spelt two ways, is one
 *  name to propose. The first spelling seen is the one kept. */
export const sagaNamesOf = (books: readonly Pick<Book, 'series'>[]): SeriesName[] => {
  const names = new Map<string, SeriesName>()
  for (const book of books) {
    if (!book.series) continue
    const key = book.series.name.toLocaleLowerCase()
    if (!names.has(key)) names.set(key, book.series.name)
  }
  return [...names.values()].sort((left, right) => left.localeCompare(right))
}

/** What the edit form proposes, from one read of the library. */
export const vocabularyOf = (
  books: readonly Pick<Book, 'series' | 'subgenres'>[],
  language: BookLanguage,
): ShelfVocabulary => ({ subgenres: subgenresOf(books, language), sagas: sagaNamesOf(books) })

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

/** Where a book lands when the reader names its saga by hand.
 *
 *  A typed name must not start a saga of its own that no catalogue knows and no
 *  other volume ever joins, so it goes, in order: to the saga the reader holds
 *  under the very key a scan would have given it, from the name and the first
 *  author; else to a saga they hold under the same name, folded as keys are —
 *  the volume a scan filed under a misspelled author, which is the one the
 *  reader is gathering; else under that key, new, exactly as a scan would have
 *  filed it, so the catalogue the series screen builds is the shared one.
 *
 *  A joined saga keeps its name as the reader's shelves already show it. The
 *  volume kind survives when the book stays in its saga, and a book moved to
 *  another is a main volume. `'no-author'` when a new key is needed and the book
 *  has no author to build it from. */
export const membershipFor = (
  placement: SeriesPlacement,
  authors: readonly AuthorName[],
  current: SeriesMembership | undefined,
  held: readonly SeriesMembership[],
): SeriesMembership | 'no-author' => {
  const derived = authors[0] ? seriesKeyOf(placement.name, authors[0]) : undefined
  const folded = slugify(placement.name)
  const joined =
    held.find((series) => series.id === derived) ??
    held.find((series) => slugify(series.name) === folded)
  const id = joined?.id ?? derived
  if (!id) return 'no-author'
  return {
    id,
    name: joined?.name ?? placement.name,
    ...(placement.volume ? { volume: placement.volume } : {}),
    kind: current?.id === id ? current.kind : 'main',
  }
}

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

/** A saga's volumes in the order the saga runs: the numbered spine, then what
 *  orbits it. */
export const inSagaOrder = <Volume extends Pick<Book, 'series' | 'title'>>(
  books: readonly Volume[],
): Volume[] =>
  [...books].sort((left, right) =>
    compareWithinSeries(
      { kind: left.series?.kind ?? 'main', number: left.series?.volume, title: left.title },
      { kind: right.series?.kind ?? 'main', number: right.series?.volume, title: right.title },
    ),
  )
