import { MAX_NOTE_LENGTH, ReadingNote } from '~/domain/book/primitives'
import type {
  Book,
  BookFormat,
  BookId,
  BookLanguage,
  BookMedium,
  BookView,
  CoverCandidate,
  CoverSource,
  CoverUrl,
  LibrarySection,
  LibraryView,
  Publisher,
  ReadingStatus,
  Recommendation,
  SeriesEntry,
  SeriesMembership,
  SeriesPlacement,
  ShelfVocabulary,
  StarRating,
  Subgenre,
  TaggedSubgenre,
} from '~/domain/book/types'
import { BOOK_MEDIA } from '~/domain/book/types'
import { compareWithinSeries } from '~/domain/series/business-rules'
import { isAudioSeries, sagaKeyFor, seriesIdOf, seriesKeyOf } from '~/domain/series/primitives'
import type { SagaKey, SeriesName } from '~/domain/series/types'
import { lovedRankOf } from '~/domain/shared/rating'
import type { AuthorName, UserId } from '~/domain/shared/types'
import { ObjectPath } from '~/system/object-store/primitives'
import type { ObjectPath as ObjectPathValue } from '~/system/object-store/types'
import { isPresent } from '~/utils/input'
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
    // The edition id holds the language: one section per saga and edition.
    const key = membership.id
    const bucket = bySeries.get(key)
    if (bucket) bucket.books.push({ book, membership })
    else
      bySeries.set(key, {
        section: {
          id: membership.id,
          saga: membership.saga,
          name: membership.name,
          language: book.language,
        },
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

/** The Amazon Associates tag every store link carries. It belongs to amazon.fr
 *  alone — a tag is bound to one store and pays nothing on another — which is
 *  why every link points there, whatever store the reader's Kindle lives on. */
export const AMAZON_ASSOCIATE_TAG = 'polyforms-21'

/** Where the book can be bought on amazon.fr, tagged. The exact product page
 *  when the record names one — its Kindle title, else the printed edition its
 *  ISBN stands for — and otherwise a search on its title and author, among
 *  recordings for an audiobook and among books for anything else. A 979 ISBN
 *  has no ISBN-10, the form Amazon's product pages answer to, so it is searched. */
export const amazonUrlOf = (
  book: Pick<Book, 'title' | 'authors' | 'format' | 'kindleAsin' | 'isbn13'>,
): string => {
  const page = (id: string) => `https://www.amazon.fr/dp/${id}?tag=${AMAZON_ASSOCIATE_TAG}`
  if (book.kindleAsin) return page(book.kindleAsin)
  const isbn10 = book.isbn13 ? isbn10Of(book.isbn13) : undefined
  if (isbn10) return page(isbn10)
  const search = new URLSearchParams({
    k: [book.title, book.authors[0]].filter(Boolean).join(' '),
    i: book.format === 'audiobook' ? 'audible' : 'stripbooks',
    tag: AMAZON_ASSOCIATE_TAG,
  })
  return `https://www.amazon.fr/s?${search}`
}

const isbn10Of = (isbn13: string): string | undefined => {
  if (!isbn13.startsWith('978')) return undefined
  const body = isbn13.slice(3, 12)
  const sum = [...body].reduce((total, digit, index) => total + Number(digit) * (10 - index), 0)
  const check = (11 - (sum % 11)) % 11
  return `${body}${check === 10 ? 'X' : check}`
}

/** The stars a book shows: its own, else the rating of its saga. A saga rated
 *  as a whole rates each volume the reader left unrated, and a rating given to
 *  the book itself always wins. `seriesRatings` is the reader's saga ratings,
 *  keyed by saga. */
export const shownRatingOf = (
  book: Pick<Book, 'rating' | 'series'>,
  seriesRatings: ReadonlyMap<SagaKey, StarRating>,
): StarRating | undefined =>
  book.rating ?? (book.series ? seriesRatings.get(book.series.saga) : undefined)

/** Where a book sits in the favourites view: its own heart or stars, else
 *  those of its saga — lent only once the book is read, as a row draws them,
 *  since on a book not yet judged they would pass for a verdict. */
export const lovedRankOfBook = (
  book: Pick<Book, 'favorite' | 'rating' | 'series' | 'status'>,
  seriesRatings: ReadonlyMap<SagaKey, StarRating>,
): number | undefined =>
  lovedRankOf({
    favorite: book.favorite,
    rating: book.rating,
    lentRating:
      book.status === 'read' && book.series ? seriesRatings.get(book.series.saga) : undefined,
  })

/** The reader's saga ratings, keyed by saga, from their opinions. */
export const seriesRatingsOf = (
  opinions: readonly { seriesId: SagaKey; rating?: StarRating }[],
): Map<SagaKey, StarRating> =>
  new Map(
    opinions.flatMap((opinion) =>
      opinion.rating === undefined ? [] : [[opinion.seriesId, opinion.rating] as const],
    ),
  )

/** The sagas the reader hearted, from their opinions: among the favourites the
 *  saga stands for its volumes, which are then not drawn one by one. */
export const heartedSagasOf = (
  opinions: readonly { seriesId: SagaKey; favorite?: boolean }[],
): Set<SagaKey> =>
  new Set(opinions.flatMap((opinion) => (opinion.favorite === true ? [opinion.seriesId] : [])))

/** The fewest stars that put a book among "Coups de cœur". */
export const LOVED_FLOOR = 4

/** What the reader said of each saga, keyed by saga: what a volume they left
 *  unrated inherits. */
export const sagaJudgementsOf = (
  opinions: readonly { seriesId: SagaKey; favorite?: boolean; rating?: StarRating }[],
): Map<SagaKey, { favorite?: boolean; rating?: StarRating }> =>
  new Map(opinions.map((opinion) => [opinion.seriesId, opinion]))

/** Whether a book sits among "Coups de cœur": hearted, rated four stars or
 *  more, or — left unrated — a volume of a saga the reader hearted or rated
 *  four stars or more, whose judgement it inherits. A volume rated on its own
 *  is judged on its own stars. */
export const isLovedBook = (
  book: Pick<Book, 'favorite' | 'rating' | 'series'>,
  sagas: ReadonlyMap<SagaKey, { favorite?: boolean; rating?: StarRating }>,
): boolean => {
  if (book.favorite === true) return true
  if (book.rating !== undefined) return book.rating >= LOVED_FLOOR
  const saga = book.series ? sagas.get(book.series.saga) : undefined
  return saga?.favorite === true || (saga?.rating ?? 0) >= LOVED_FLOOR
}

/** Whether a book is drawn on its own among the favourites: not a volume of a
 *  saga the reader hearted, which the saga's card already stands for. */
export const outsideHeartedSagas = (
  book: Pick<Book, 'series'>,
  heartedSagas: ReadonlySet<SagaKey>,
): boolean => !book.series || !heartedSagas.has(book.series.saga)

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

/** How far ahead of the server a typed date may sit: the reader's phone picks
 *  "today" on its own clock, which can run ahead. */
const CLOCK_DRIFT_MS = 86_400_000

/** The reading dates in the order a book lives through them. */
const READING_DATES = ['addedAt', 'startedAt', 'finishedAt'] as const

/** The reading dates a reader corrected by hand, or `bad-dates` when they cannot
 *  be true: a date that does not parse, one in the future, two typed together
 *  out of order, or a date the status does not carry — a book on the pile was
 *  never opened, and only a read one was finished.
 *
 *  A typed date is never refused for contradicting one already stored: it is
 *  the reader's latest word, and the stored dates follow it. A start set before
 *  the arrival brings the arrival back to it; a start set after the finish
 *  carries the finish along; and so on down the line, added, started, finished.
 *
 *  Correcting the date that marks the current status — the finish of a read
 *  book, the start of one in progress, the arrival of one on the pile — also
 *  moves the status stamp the library is ordered on: the reader is saying when
 *  that move happened. A date carried along by another moves it the same way.
 *  A dropped book keeps its stamp, since no typed date says when it was
 *  dropped. */
export const datesAfterCorrection = (
  book: Pick<Book, 'status' | 'addedAt' | 'startedAt' | 'finishedAt'>,
  typed: Partial<Pick<Book, 'addedAt' | 'startedAt' | 'finishedAt'>>,
  now: Date,
):
  | Partial<Pick<Book, 'addedAt' | 'startedAt' | 'finishedAt' | 'statusChangedAt'>>
  | 'bad-dates' => {
  const latest = now.getTime() + CLOCK_DRIFT_MS
  const unbelievable = (date?: Date) =>
    date !== undefined && (Number.isNaN(date.getTime()) || date.getTime() > latest)
  if (Object.values(typed).some(unbelievable)) return 'bad-dates'
  if (typed.startedAt && book.status === 'to-read') return 'bad-dates'
  if (typed.finishedAt && book.status !== 'read') return 'bad-dates'
  const typedInOrder = READING_DATES.flatMap((field) => typed[field] ?? [])
  if (typedInOrder.some((date, index) => index > 0 && date < typedInOrder[index - 1]))
    return 'bad-dates'

  const dates: Partial<Pick<Book, 'addedAt' | 'startedAt' | 'finishedAt'>> = {
    addedAt: book.addedAt,
    startedAt: book.startedAt,
    finishedAt: book.finishedAt,
    ...typed,
  }
  const moved: Partial<Pick<Book, 'addedAt' | 'startedAt' | 'finishedAt'>> = { ...typed }
  READING_DATES.forEach((field, index) => {
    const anchor = typed[field]
    if (!anchor) return
    READING_DATES.forEach((other, otherIndex) => {
      const date = dates[other]
      if (!date || typed[other]) return
      const outOfOrder = otherIndex < index ? date > anchor : otherIndex > index && date < anchor
      if (!outOfOrder) return
      dates[other] = anchor
      moved[other] = anchor
    })
  })

  const marking = { read: moved.finishedAt, reading: moved.startedAt, 'to-read': moved.addedAt }
  const stamp = book.status === 'dropped' ? undefined : marking[book.status]
  return { ...moved, ...(stamp ? { statusChangedAt: stamp } : {}) }
}

/** The reading dates a reader set on a book before saving it — on the scan
 *  review — or `bad-dates` when they cannot be true, by the same measure as a
 *  correction of a book catalogued a moment ago in that status. */
export const datesOnArrival = (
  status: ReadingStatus,
  typed: Partial<Pick<Book, 'startedAt' | 'finishedAt'>>,
  now: Date,
): Partial<Pick<Book, 'startedAt' | 'finishedAt'>> | 'bad-dates' =>
  datesAfterCorrection({ status, addedAt: now }, typed, now) === 'bad-dates' ? 'bad-dates' : typed

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
 *  another is a main volume. A saga of the other format is never joined, even
 *  under the same name: the saga heard and the saga read are two sagas.
 *  `'no-author'` when a new key is needed and the book has no author to build
 *  it from. */
export const membershipFor = (
  placement: SeriesPlacement,
  authors: readonly AuthorName[],
  format: BookFormat,
  language: BookLanguage | undefined,
  current: SeriesMembership | undefined,
  held: readonly SeriesMembership[],
): SeriesMembership | 'no-author' => {
  const derived = authors[0] ? seriesKeyOf(placement.name, authors[0], format) : undefined
  const folded = slugify(placement.name)
  // The saga heard and the saga read share a name and are still two sagas.
  const heard = format === 'audiobook'
  const joined =
    held.find((series) => series.saga === derived) ??
    held.find((series) => isAudioSeries(series.saga) === heard && slugify(series.name) === folded)
  const saga = joined?.saga ?? derived
  if (!saga) return 'no-author'
  return membershipIn(
    {
      saga,
      name: joined?.name ?? placement.name,
      ...(placement.volume ? { volume: placement.volume } : {}),
      kind: current?.saga === saga ? current.kind : 'main',
    },
    format,
    language,
  )
}

/** The membership a book is written with: its saga in the format it is taken
 *  in — a book turned audiobook leaves the saga read for the saga heard, and
 *  back — and the series id of that saga in the book's language. Where every
 *  edition id is built, when the book is written: a reader of the book takes
 *  the id it finds. */
export const membershipIn = (
  series: SeriesEntry,
  format: BookFormat,
  language: BookLanguage | undefined,
): SeriesMembership => {
  const saga = sagaKeyFor(series.saga, format)
  return { ...series, id: seriesIdOf(saga, language), saga }
}

/** A book about to be written, its membership filed under the edition its own
 *  format and language make: what keeps the stored id true when either
 *  changes. */
export const inItsEdition = <B extends Pick<Book, 'series' | 'format' | 'language'>>(book: B): B =>
  book.series ? { ...book, series: membershipIn(book.series, book.format, book.language) } : book

/** The Library tab's order: newest first on the date that last moved each
 *  book, a flat list the app cuts into month sections wherever the month of
 *  that date changes, so the server alone decides what sits where. Sagas are
 *  not gathered: a volume sits on its own date, and the Series tab is where a
 *  saga is read whole. */
export const shelvedOf = <T extends Book>(books: readonly T[]): T[] => [...books].sort(shelfOrder)

type ShelvedBook = { title: string } & Pick<
  Book,
  'addedAt' | 'startedAt' | 'finishedAt' | 'listenedAt'
>

/** Which of two books the Library tab shelves first: the newest on its shelf
 *  date, then by title in code-point order — Firestore's own, which the tab's
 *  index pages on, so every list that follows the tab ties the way it does. */
export const shelfOrder = (left: ShelvedBook, right: ShelvedBook): number =>
  shelfDateOf(right).getTime() - shelfDateOf(left).getTime() ||
  shelfTitleOrder(left.title, right.title)

/** How the Library tab ties two books shelved the same day: by title in
 *  code-point order, as Firestore orders strings. */
export const shelfTitleOrder = (left: string, right: string): number =>
  left < right ? -1 : left > right ? 1 : 0

/** The date a book is shelved on, whatever its status: the day it was
 *  finished, else the day it was last read, else the day it was added. A record
 *  whose reading dates were never stamped — an import, a book from before the
 *  dates existed — falls back to the day it was added.
 *
 *  A started recording is last read the day the player last moved, which
 *  Audible dates: the one the reader is listening to leads the books under way,
 *  however late another was marked started. A status put right by hand is not a
 *  listening. Without a position, the day it was started. */
export const shelfDateOf = (
  book: Pick<Book, 'addedAt' | 'startedAt' | 'finishedAt' | 'listenedAt'>,
): Date =>
  book.finishedAt ??
  (book.startedAt ? (book.listenedAt ?? book.startedAt) : undefined) ??
  book.addedAt

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

/** The title and first author folded together: whether the reader already owns
 *  this story, loosely and across editions. A novel scanned from the printed
 *  edition is the same story as its Audible recording, and a friend's copy of
 *  it is one the reader already has.
 *
 *  Loose on purpose, and not an identity: the ASIN of an imported record is the
 *  precise answer to "which record is this exact Audible title", which is what
 *  the sync writes a status into. */
export const shelfKeyOf = (title: string, author: string | undefined): string =>
  `${slugify(title)}--${slugify(author ?? '')}`

export const shelfKeysOf = (books: readonly Book[]): Set<string> =>
  new Set(books.map((book) => shelfKeyOf(book.title, book.authors[0])))

/** Whether two names say the same story, looser than the shelf key: the same
 *  title, by authors who agree (`sameAuthor`). A spine prints "Barjavel" where
 *  the record says "René Barjavel", and a photo misreads "WILLIAM GIBSON" as
 *  "ILLIAM GIBSON": keyed on the whole name, a shelf photo offered books the
 *  reader already kept, ticked, and added them twice. Only compared, never
 *  stored — the keys kept in Firestore (awaited editions, awards, suggestions)
 *  stay on `shelfKeyOf`. */
export const sameStory = (
  left: { title: string; author?: string },
  right: { title: string; author?: string },
): boolean => slugify(left.title) === slugify(right.title) && sameAuthor(left.author, right.author)

/** Whether the reader already keeps this story, under any record. */
export const keepsStory = (
  books: readonly { title: string; authors: readonly string[] }[],
  story: { title: string; author?: string },
): boolean => books.some((book) => sameStory({ title: book.title, author: book.authors[0] }, story))

/** Whether two spellings name one author: the same last name, and first names
 *  that agree where both are given — one letter apart at most, a misread
 *  initial. "Barjavel" is René Barjavel; Brian Herbert is not Frank Herbert. */
export const sameAuthor = (left: string | undefined, right: string | undefined): boolean => {
  const [a, b] = [namePartsOf(left), namePartsOf(right)]
  if (a.length === 0 || b.length === 0) return a.length === b.length
  if (a.at(-1) !== b.at(-1)) return false
  const [givenA, givenB] = [a.slice(0, -1).join(''), b.slice(0, -1).join('')]
  return givenA === '' || givenB === '' || lettersApart(givenA, givenB) <= 1
}

/** How a store, a pasted link or a picked candidate names the author beside a
 *  title: across a dash set apart by spaces, or in brackets at the end. A
 *  comma or a colon is no such mark — "Moi, Christiane F." is the title of
 *  Christiane F.'s book. */
const AUTHOR_DASH = /\s+[-–—]\s+/gu
const AUTHOR_IN_BRACKETS = /^(.+?)\s*\(([^()]+)\)$/u

/** The title without one of its own authors named beside it, before or after:
 *  "La Horde du Contrevent — Alain Damasio", "Damasio - La Horde du
 *  Contrevent" and "La Horde du Contrevent (Alain Damasio)" by Alain Damasio
 *  are "La Horde du Contrevent". Unchanged when what stands beside the dash is
 *  no author of the book (`sameAuthor`): "Dune — Le Messie" keeps its dash.
 *  What it returns is a part of the title, never empty, so a checked title
 *  stays one. */
export const titleWithoutAuthor = <Title extends string>(
  title: Title,
  authors: readonly string[],
): Title => {
  const byItsAuthor = (name: string) => authors.some((author) => sameAuthor(name, author))
  const bracketed = title.match(AUTHOR_IN_BRACKETS)
  if (bracketed && byItsAuthor(bracketed[2])) return bracketed[1].trim() as Title
  return (dashSplitsOf(title).find(({ named }) => byItsAuthor(named))?.rest ?? title) as Title
}

/** Every way to read a title as a name across a dash from the rest: the name
 *  last, cut at the last dash, then the name first, cut at the first. */
const dashSplitsOf = (title: string): { rest: string; named: string }[] => {
  const dashes = [...title.matchAll(AUTHOR_DASH)]
  const [first, last] = [dashes[0], dashes.at(-1)]
  if (!first || !last) return []
  const before = (dash: RegExpExecArray) => title.slice(0, dash.index).trim()
  const after = (dash: RegExpExecArray) => title.slice(dash.index + dash[0].length).trim()
  return [
    { rest: before(last), named: after(last) },
    { rest: after(first), named: before(first) },
  ].filter(({ rest, named }) => rest !== '' && named !== '')
}

const namePartsOf = (name: string | undefined) =>
  slugify(name ?? '')
    .split('-')
    .filter(Boolean)

/** How many letters to change, add or drop to turn one word into the other. */
const lettersApart = (left: string, right: string): number => {
  let previous = Array.from({ length: right.length + 1 }, (_, index) => index)
  for (let i = 1; i <= left.length; i++) {
    const current = [i]
    for (let j = 1; j <= right.length; j++)
      current[j] = Math.min(
        previous[j] + 1,
        current[j - 1] + 1,
        previous[j - 1] + (left[i - 1] === right[j - 1] ? 0 : 1),
      )
    previous = current
  }
  return previous[right.length]
}

/** One copy the reader keeps of a story: what tells it from another volume or
 *  another language under the same title. */
export type ShelfCopy = { volume?: number; language?: BookLanguage }

/** The reader's books by shelf key, as an import checks a title against them. */
export type Shelf = ReadonlyMap<string, readonly ShelfCopy[]>

export const shelfOf = (books: readonly Book[]): Shelf => {
  const shelf = new Map<string, ShelfCopy[]>()
  for (const book of books) {
    const key = shelfKeyOf(book.title, book.authors[0])
    shelf.set(key, [
      ...(shelf.get(key) ?? []),
      { volume: book.series?.volume, language: book.language },
    ])
  }
  return shelf
}

/** Whether the reader already keeps this title, by its shelf key — except that
 *  a saga whose volumes share one title ("Primal Hunter" 4, 5 and 6 on Audible)
 *  is told apart by volume, and a recording in English from the French one by
 *  language. A side that does not say matches: the check stays as loose as the
 *  key wherever nothing tells two copies apart. */
export const keepsCopyOf = (
  shelf: Shelf,
  candidate: { title: string; author?: string; volume?: number; language?: BookLanguage },
): boolean =>
  (shelf.get(shelfKeyOf(candidate.title, candidate.author)) ?? []).some(
    (copy) => agrees(copy.volume, candidate.volume) && agrees(copy.language, candidate.language),
  )

const agrees = <T>(kept: T | undefined, candidate: T | undefined) =>
  kept === undefined || candidate === undefined || kept === candidate

/** The record the reader already keeps of a book about to be added: the same
 *  story by its shelf key, or the same edition by its ISBN, which still matches
 *  when the title was read differently off the cover. The earliest on the shelf
 *  wins — the copy the reader thinks of as theirs.
 *
 *  A warning, never a refusal: two editions of one story — the paperback and
 *  the recording — are a library some readers keep on purpose. */
export const copyOf = <T extends Book>(
  books: readonly T[],
  candidate: { title: string; authors: readonly string[]; isbn13?: string },
): T | undefined => {
  const story = { title: candidate.title, author: candidate.authors[0] }
  return books
    .filter(
      (book) =>
        sameStory({ title: book.title, author: book.authors[0] }, story) ||
        (candidate.isbn13 !== undefined && book.isbn13 === candidate.isbn13),
    )
    .toSorted((a, b) => a.addedAt.getTime() - b.addedAt.getTime())[0]
}

/** Where a book of this format is held, from what a source said of it: a
 *  recording is heard, so it is held on neither; a read book is on paper unless
 *  something said otherwise. Always in the order paper, screen, so two records
 *  held the same way compare equal. */
export const mediaFor = (format: BookFormat, media: readonly BookMedium[] = []): BookMedium[] => {
  if (format === 'audiobook') return []
  const held = BOOK_MEDIA.filter((medium) => media.includes(medium))
  return held.length > 0 ? held : ['print']
}

/** The record a book arriving on another medium joins, rather than doubling:
 *  the same story by `sameStory` or the same edition by its ISBN, read
 *  rather than heard, in the same volume and language wherever both say, and
 *  not yet held on every medium the arrival brings. The paperback scanned after
 *  the Kindle copy is one book, not two; a French paperback and an English
 *  Kindle copy are two editions, as their sagas are. The earliest on the shelf
 *  wins, as for `copyOf`. */
export const recordJoinedBy = <T extends Book>(
  books: readonly T[],
  arriving: Pick<Book, 'title' | 'authors' | 'isbn13' | 'format' | 'media' | 'language'> & {
    series?: Pick<SeriesMembership, 'volume'>
  },
): T | undefined => {
  if (arriving.format === 'audiobook') return undefined
  const story = { title: arriving.title, author: arriving.authors[0] }
  return books
    .filter(
      (book) =>
        book.format !== 'audiobook' &&
        (sameStory({ title: book.title, author: book.authors[0] }, story) ||
          (arriving.isbn13 !== undefined && book.isbn13 === arriving.isbn13)) &&
        agrees(book.series?.volume, arriving.series?.volume) &&
        agrees(book.language, arriving.language) &&
        arriving.media.some((medium) => !book.media.includes(medium)),
    )
    .toSorted((a, b) => a.addedAt.getTime() - b.addedAt.getTime())[0]
}

/** How far along a reading each status is, for two copies of one book to keep
 *  the furthest: finished beats dropped, which beats begun, which beats the
 *  pile. */
const PROGRESS: Record<ReadingStatus, number> = { 'to-read': 0, reading: 1, dropped: 2, read: 3 }

const earliest = (...dates: (Date | undefined)[]): Date | undefined =>
  dates.filter(isDefined).toSorted((a, b) => a.getTime() - b.getTime())[0]

const latest = (...dates: (Date | undefined)[]): Date | undefined =>
  dates.filter(isDefined).toSorted((a, b) => b.getTime() - a.getTime())[0]

const isDefined = <T>(value: T | undefined): value is T => value !== undefined

/** Two copies of one book — on paper and on a screen — as the one record the
 *  reader keeps of it.
 *
 *  `kept` names the record: its id, and every fact it already states. `other`
 *  fills what `kept` leaves blank, and lends a drawn format (manga, comic) over
 *  the plain `book` a Kindle title is always filed as. Where both said
 *  something about the reading, the furthest along wins: the furthest status,
 *  the earliest start and the latest finish, the higher rating, either heart,
 *  both notes one after the other. A book either copy hid stays hidden. */
export const mergedCopies = (kept: Book, other: Book, now: Date): Book => {
  const format = kept.format === 'book' ? other.format : kept.format
  const status = PROGRESS[other.status] > PROGRESS[kept.status] ? other.status : kept.status
  const finishing = [kept, other].filter((copy) => copy.status === 'read')
  const hearted = [kept, other].filter((copy) => copy.favorite)
  const notes = [kept.note, other.note].filter(isDefined)
  const ratings = [kept.rating, other.rating].filter(isDefined)
  return {
    ...other,
    ...withoutAbsent(kept),
    format,
    media: mediaFor(format, [...kept.media, ...other.media]),
    authors: kept.authors.length > 0 ? kept.authors : other.authors,
    subgenres: kept.subgenres.length > 0 ? kept.subgenres : other.subgenres,
    narrators: kept.narrators.length > 0 ? kept.narrators : other.narrators,
    status,
    rating: ratings.toSorted((a, b) => b - a)[0],
    favorite: hearted.length > 0 ? true : undefined,
    favoritedAt: earliest(...hearted.map((copy) => copy.favoritedAt)),
    note: notes.length > 0 ? ReadingNote(notes.join('\n\n').slice(0, MAX_NOTE_LENGTH)) : undefined,
    hidden: kept.hidden || other.hidden,
    // Described if either copy was: the record keeps the facts of the one that was.
    awaitingDescription: kept.awaitingDescription && other.awaitingDescription ? true : undefined,
    addedAt: earliest(kept.addedAt, other.addedAt) ?? kept.addedAt,
    startedAt: status === 'to-read' ? undefined : earliest(kept.startedAt, other.startedAt),
    finishedAt: latest(...finishing.map((copy) => copy.finishedAt)),
    statusChangedAt: latest(kept.statusChangedAt, other.statusChangedAt),
    updatedAt: now,
  }
}

const withoutAbsent = <T extends object>(record: T): Partial<T> =>
  Object.fromEntries(
    Object.entries(record).filter(([, value]) => value !== undefined),
  ) as Partial<T>

/** The sources a book's cover is drawn from, folded into the two every drawing
 *  site reads: the cover the reader picked first, then the Kindle cover — it is
 *  the one the reader sees on their Kindle — then the reader's own photo, then
 *  the publisher's. A photo picked that is no longer there picks nothing. */
export const coverSourcesOf = (
  book: Pick<Book, 'chosenCover' | 'kindleCoverUrl' | 'coverPath' | 'publishedCoverUrl'>,
): Pick<Book, 'coverPath' | 'publishedCoverUrl'> => {
  if (book.chosenCover?.source === 'url') return { publishedCoverUrl: book.chosenCover.url }
  if (book.chosenCover?.source === 'photo' && book.coverPath) return { coverPath: book.coverPath }
  if (book.kindleCoverUrl) return { publishedCoverUrl: book.kindleCoverUrl }
  return withoutAbsent({ coverPath: book.coverPath, publishedCoverUrl: book.publishedCoverUrl })
}

const AMAZON_IMAGE_HOSTS = ['m.media-amazon.com', 'images-na.ssl-images-amazon.com']

/** The source an image address belongs to, told by its host: a cover stored
 *  without saying where it came from — the publisher's, or one the reader
 *  picked — is named as the picker names the fresh ones. */
export const coverSourceOfAddress = (
  url: CoverUrl,
): Exclude<CoverSource, 'photo' | 'kindle' | 'other-edition'> => {
  const host = URL.parse(url)?.hostname
  if (host && AMAZON_IMAGE_HOSTS.includes(host)) return 'amazon'
  if (host === 'covers.openlibrary.org') return 'open-library'
  return 'web'
}

/** What a cover lookup found for a book: the sources asked by its own ISBN, and
 *  the covers of its other editions in the same language. */
export type CoversFound = {
  amazon?: CoverUrl
  openLibrary?: CoverUrl
  /** The French booksellers' image server: offered as a web cover, since the
   *  picker names no source for it. */
  epagine?: CoverUrl
  otherEditions: readonly CoverUrl[]
}

/** The covers a reader may pick for a book, each image once, the one drawn now
 *  first: what the record already holds — the Kindle cover, the photo, the
 *  publisher's, the one picked — and what a fresh lookup found. A Kindle cover
 *  also served by Amazon is offered as the Kindle one. */
export const coverCandidatesOf = (
  book: Pick<Book, 'chosenCover' | 'kindleCoverUrl' | 'coverPath' | 'publishedCoverUrl'>,
  found: CoversFound,
): CoverCandidate[] => {
  const drawn = coverSourcesOf(book)
  const offered: CoverCandidate[] = []
  const seen = new Set<string>()
  const offer = (source: Exclude<CoverSource, 'photo'>, url: CoverUrl | undefined) => {
    if (!url || seen.has(url)) return
    seen.add(url)
    offered.push({ source, url, current: !drawn.coverPath && drawn.publishedCoverUrl === url })
  }
  offer('kindle', book.kindleCoverUrl)
  if (book.coverPath) offered.push({ source: 'photo', current: drawn.coverPath !== undefined })
  if (book.publishedCoverUrl)
    offer(coverSourceOfAddress(book.publishedCoverUrl), book.publishedCoverUrl)
  offer('amazon', found.amazon)
  offer('open-library', found.openLibrary)
  offer('web', found.epagine)
  for (const url of found.otherEditions) offer('other-edition', url)
  if (book.chosenCover?.source === 'url')
    offer(coverSourceOfAddress(book.chosenCover.url), book.chosenCover.url)
  return [
    ...offered.filter((choice) => choice.current),
    ...offered.filter((choice) => !choice.current),
  ]
}

/** What a record keeps of its Kindle title once its media are settled: a book
 *  no longer held on a screen is no Kindle title's, so the nightly sync can
 *  never move its status again, and its Kindle cover goes with it. */
export const kindleLinkUnder = (
  book: Pick<Book, 'kindleAsin' | 'kindleCoverUrl'>,
  media: readonly BookMedium[],
): Pick<Book, 'kindleAsin' | 'kindleCoverUrl'> =>
  media.includes('digital')
    ? { kindleAsin: book.kindleAsin, kindleCoverUrl: book.kindleCoverUrl }
    : { kindleAsin: undefined, kindleCoverUrl: undefined }

/** What a fresh lookup of the book found, as the scan answers it. */
export type LookedUp = Partial<
  Pick<Book, 'firstPublishedIn' | 'synopsis' | 'genre' | 'pageCount' | 'isbn13'>
> & { subgenres?: readonly Subgenre[]; coverUrl?: Book['publishedCoverUrl'] }

/** What a fresh lookup named the book: title, authors, publisher, saga. */
export type NamedByLookup = {
  /** Empty when the lookup named no title. */
  title?: Book['title'] | ''
  authors?: readonly AuthorName[]
  publisher?: Publisher
  series?: { name: SeriesName }
}

/** The spelling a lookup found for a name the record holds, when it does no
 *  more than mend a misread: a spine read puts a space inside a word, before
 *  the accented letter — "La vall ée de la peur", "Le Myst ère de la chambre
 *  jaune", "Henri L üvenbruck" — and a lookup made from that name finds it
 *  whole. Only a name the lookup writes in fewer words, and otherwise the same
 *  but for one letter, is taken: anything further apart is another name, and
 *  the record's stays. Undefined when there is nothing to mend. */
export const mendedSpelling = <Name extends string>(
  held: Name | undefined,
  found: Name | undefined,
): Name | undefined => {
  if (!held || !found || wordsIn(found) >= wordsIn(held)) return undefined
  return lettersApart(spaceless(held), spaceless(found)) <= 1 ? found : undefined
}

const wordsIn = (name: string) => name.trim().split(/\s+/u).length

const spaceless = (name: string) => name.normalize('NFC').replace(/\s+/gu, '').toLowerCase()

/** The record's authors, each one a lookup spelled whole put in its place. */
const mendedAuthors = (
  held: readonly AuthorName[],
  found: readonly AuthorName[],
): AuthorName[] | undefined => {
  const mended = held.map(
    (author) => found.map((other) => mendedSpelling(author, other)).find(isPresent) ?? author,
  )
  return mended.some((author, index) => author !== held[index]) ? mended : undefined
}

/** The names a book takes from a fresh lookup: none, but those its record
 *  holds misread with a space inside a word (`mendedSpelling`) — the title,
 *  each author, the publisher, the saga's name. Everything else that names the
 *  book is what the lookup was made from, and stays the reader's.
 *
 *  A saga is keyed on its name and its first author, so when either is mended
 *  the book is placed in its saga again, under the name it now has, for the
 *  edit to key it as a reader's correction would. */
export const mendedNames = (
  book: Pick<Book, 'title' | 'authors' | 'publisher' | 'series'>,
  found: NamedByLookup,
): Partial<Pick<Book, 'title' | 'authors' | 'publisher'>> & { series?: SeriesPlacement } => {
  const authors = mendedAuthors(book.authors, found.authors ?? [])
  const seriesName = mendedSpelling(book.series?.name, found.series?.name)
  const series =
    book.series && (seriesName || (authors?.[0] !== undefined && authors[0] !== book.authors[0]))
      ? { name: seriesName ?? book.series.name, volume: book.series.volume }
      : undefined
  return Object.fromEntries(
    Object.entries({
      title: mendedSpelling(book.title, found.title || undefined),
      authors,
      publisher: mendedSpelling(book.publisher, found.publisher),
      series,
    }).filter(([, value]) => value !== undefined),
  )
}

/** The facts a book takes from a fresh lookup when the reader asks for its
 *  record to be brought up to date.
 *
 *  Only what describes the work is rewritten: summary, genre, subgenres, page
 *  count, year, published cover. What names the book — title, authors, format,
 *  language, publisher, saga — is what the lookup was made from, so it stays
 *  the reader's, misreads aside (`mendedNames`). So does an ISBN already on the record: it names the edition on
 *  the shelf, where the lookup only guesses one, and is filled in only when
 *  missing. A field the lookup did not find keeps what the book had: a refresh
 *  fills and corrects, it never empties. A recording has no page count,
 *  whatever the lookup says of the printed book. */
export const refreshedFacts = (
  book: Pick<Book, 'format' | 'language' | 'isbn13'>,
  found: LookedUp,
  language: BookLanguage,
): Partial<
  Pick<
    Book,
    | 'firstPublishedIn'
    | 'synopsis'
    | 'genre'
    | 'pageCount'
    | 'isbn13'
    | 'publishedCoverUrl'
    | 'subgenres'
  >
> => {
  const subgenres = found.subgenres ?? []
  return Object.fromEntries(
    Object.entries({
      firstPublishedIn: found.firstPublishedIn,
      synopsis: found.synopsis,
      genre: found.genre,
      pageCount: book.format === 'audiobook' ? undefined : found.pageCount,
      isbn13: book.isbn13 ? undefined : found.isbn13,
      publishedCoverUrl: found.coverUrl,
      subgenres: subgenres.length > 0 ? taggedIn(subgenres, book.language ?? language) : undefined,
    }).filter(([, value]) => value !== undefined),
  )
}

/** The format a subgenre names, if it names one: "Bande dessinée", "BD",
 *  "Manga", "Comics". */
const FORMAT_SUBGENRES: Record<string, BookFormat> = {
  'bande dessinee': 'bande-dessinee',
  bd: 'bande-dessinee',
  manga: 'manga',
  comic: 'comic',
  comics: 'comic',
}

const formatNamedBy = (subgenre: string): BookFormat | undefined =>
  FORMAT_SUBGENRES[
    subgenre
      .normalize('NFD')
      .replace(/\p{Diacritic}/gu, '')
      .toLowerCase()
      .replace(/[^a-z]+/g, ' ')
      .trim()
  ]

/** A book's format settled by its subgenres: a web search that files a book
 *  under "Bande dessinée" says what the object is, where a cover read as a
 *  book, or not settled at all, did not. Only a printed book is corrected —
 *  a manga, a comic or a recording read on the cover is kept — and the
 *  subgenre that named the format leaves the list, the format having its own
 *  tile. */
export const formatSettledBySubgenres = <S extends string>(
  format: BookFormat | undefined,
  subgenres: readonly S[],
): { format: BookFormat | undefined; subgenres: S[] } => {
  if (format !== undefined && format !== 'book') return { format, subgenres: [...subgenres] }
  const named = subgenres.map(formatNamedBy).find(isPresent)
  if (!named) return { format, subgenres: [...subgenres] }
  return {
    format: named,
    subgenres: subgenres.filter((subgenre) => formatNamedBy(subgenre) === undefined),
  }
}

/** The book belongs to the format, genre and subgenre a view of the Library
 *  tab is narrowed to. A subgenre matches whatever its case, as the reader
 *  typed it or a scan wrote it. */
export const inLibraryView = (
  book: Pick<Book, 'format' | 'genre' | 'subgenres'>,
  view: Pick<LibraryView, 'format' | 'genre' | 'subgenre'>,
): boolean => {
  if (view.format && book.format !== view.format) return false
  if (view.genre && book.genre !== view.genre) return false
  if (view.subgenre) {
    const wanted = view.subgenre.toLocaleLowerCase()
    if (!book.subgenres.some((tagged) => tagged.label.toLocaleLowerCase() === wanted)) return false
  }
  return true
}
