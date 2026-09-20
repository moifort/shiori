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
  lastActivityAt: Date
}

/** The materialized view behind the home dashboard, one document per reader.
 *
 *  It holds raw aggregates rather than rendered figures: anything that depends on
 *  today's date is derived when the dashboard is read, so the view never goes
 *  stale by the calendar alone — only by a write to a book, which rebuilds it. */
export type AnalyticsView = {
  userId: UserId
  timeZone: TimeZone
  /** Set in the same batch as any book write, cleared by the rebuild that
   *  follows. A view left stale by a failed rebuild is rebuilt on read. */
  stale: boolean
  refreshedAt: Date
  finishes: Finish[]
  /** Most recently started first. */
  reading: BookCard[]
  toRead: BookCard[]
  lastFinished?: BookCard
  series: SeriesProgress[]
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
  monthsToClearPile?: number
  averageRating?: number
  ratedCount: number
  genres: GenreCount[]
  series: SeriesProgress[]
  libraryIsEmpty: boolean
}
