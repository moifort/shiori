import type { Brand } from 'ts-brand'
import type {
  BookId,
  CoverUrl,
  Genre,
  ListeningMinutes,
  PageCount,
  StarRating,
} from '~/domain/book/types'
import type { SeriesId, SeriesName } from '~/domain/series/types'
import type { AuthorName, BookTitle, UserId } from '~/domain/shared/types'
import type { ObjectPath, SignedUrl } from '~/system/object-store/types'

/** An IANA time zone identifier the runtime knows, such as "Europe/Paris". Every
 *  day, month and year of the statistics is taken in it: a book finished on
 *  December 31st at 23:00 in Paris belongs to that year, not the next. */
export type TimeZone = Brand<string, 'TimeZone'>

/** A calendar day in the reader's time zone, as `YYYY-MM-DD`. A date without a
 *  time on purpose: the statistics count days, and an instant would drag a time
 *  zone conversion into every comparison. */
export type LocalDate = Brand<string, 'LocalDate'>

/** A book as the dashboard draws it: enough for a cover tile, nothing more. The
 *  cover is stored as its source, never as a signed URL, which expires. */
export type BookCard = {
  id: BookId
  title: BookTitle
  authors: AuthorName[]
  coverPath?: ObjectPath
  publishedCoverUrl?: CoverUrl
  rating?: StarRating
  /** How far into a recording the player last stopped, in whole percent. Only
   *  on an audiobook the Audible player opened. */
  listeningProgress?: number
  startedAt?: Date
  finishedAt?: Date
}

/** One finished book, reduced to what the statistics read. Dates are local days
 *  in the time zone the view was built in. */
export type Finish = {
  bookId: BookId
  startedOn: LocalDate
  finishedOn: LocalDate
  pageCount?: PageCount
  /** An audiobook's running time. What the listening hours count, the way the
   *  page count is what the reading pages count. */
  durationMinutes?: ListeningMinutes
  genre?: Genre
  rating?: StarRating
}

/** How far the reader is through a saga in progress, against the published main
 *  volumes of the shared catalogue at the time the view was built. */
export type SeriesProgress = {
  id: SeriesId
  name: SeriesName
  readCount: number
  totalCount: number
  /** What the reader thinks of the saga — its own rating, else the average of
   *  its rated volumes — which ranks the dashboard's card. Absent when they
   *  have rated neither, and on a view stored before the field existed. */
  rating?: number
  /** The reader hearted the saga: drawn as the heart, which is five stars. */
  favorite: boolean
  lastActivityAt: Date
}

/** The materialized view behind the home dashboard, one document per reader.
 *
 *  It holds raw aggregates rather than rendered figures: anything that depends on
 *  today's date is derived when the dashboard is read, so the view never goes
 *  stale by the calendar alone — only by a write to a book, which marks it so
 *  for the next dashboard read to rebuild. */
export type AnalyticsView = {
  userId: UserId
  timeZone: TimeZone
  /** The shape this view was built with. A view built by an older rule set is
   *  rebuilt on read rather than served with a figure it never computed. */
  version?: number
  /** Set in the same batch as any book write, cleared by the rebuild the next
   *  dashboard read runs. Ten ratings in a row cost one rebuild, not ten. */
  stale: boolean
  refreshedAt: Date
  finishes: Finish[]
  /** Most recently started first. */
  reading: BookCard[]
  toRead: BookCard[]
  lastFinished?: BookCard
  series: SeriesProgress[]
  /** Books and sagas the reader keeps close, counted apart because a saga is
   *  hearted once whatever the number of its volumes on the shelf. */
  favoriteBookCount?: number
  favoriteSeriesCount?: number
  /** How many recordings the library holds — what decides whether the listening
   *  hours are worth a chart at all. */
  audiobookCount?: number
  /** How many books have pages — every format but the recording — which decides
   *  the same for the pages. A view stored before it answers nothing, read as
   *  pages to chart rather than as a library of recordings only. */
  printedBookCount?: number
  /** Books the reader stopped because they did not like them. */
  droppedCount?: number
}

export type YearCount = { year: number; count: number }
export type MonthPages = { month: number; pages: number }
export type MonthHours = { month: number; hours: number }

/** A figure for this year to date, beside the same span of last year. `previous`
 *  is absent when last year has nothing to compare against. */
export type Trend = { current?: number; previous?: number }

/** One segment of the genre bar. An absent genre is the "others" segment. */
export type GenreCount = { genre?: Genre; count: number }

export type DashboardBook = Omit<BookCard, 'coverPath' | 'publishedCoverUrl'> & {
  coverUrl?: SignedUrl | CoverUrl
}

/** The dashboard as it is served: the view read against today. Built with the
 *  stored cards first, then served with their covers signed. */
export type Dashboard<Card = DashboardBook> = {
  currentYear: number
  booksPerYear: YearCount[]
  pagesPerMonth: MonthPages[]
  hoursPerMonth: MonthHours[]
  reading: Card[]
  suggestions: Card[]
  lastFinished?: Card
  pagesPerDay: Trend
  daysToFinish: Trend
  toReadCount: number
  /** Every book finished since the first, whatever the year. */
  readCount: number
  monthsToClearPile?: number
  averageRating?: number
  ratedCount: number
  genres: GenreCount[]
  series: SeriesProgress[]
  /** Books and sagas hearted, together. */
  favoriteCount: number
  /** Whether a single recording is on the shelf. */
  hasAudiobooks: boolean
  /** Whether a single book with pages is on the shelf. */
  hasPrintedBooks: boolean
  /** Books dropped, the reader not having liked them. */
  droppedCount: number
  libraryIsEmpty: boolean
}
