import type { Brand } from 'ts-brand'
import type {
  BookFormat,
  BookId,
  BookLanguage,
  CoverUrl,
  Genre,
  ListeningMinutes,
  PageCount,
  SeriesMembership,
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
  /** A recording's cover carries the headphones, on the dashboard as anywhere. */
  format: BookFormat
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
  /** What the reader's friends may see of the shelf. Absent on a view stored
   *  before friends saw counts. */
  shared?: SharedShelf
}

/** The shelf as a friend sees it, counted apart from the dashboard's figures
 *  because every figure above counts the books marked "do not share" too. Here
 *  they are left out before anything is counted, so a friend can never tell
 *  from a number that something is being kept from them. */
export type SharedShelf = {
  /** Every book shared, the dropped ones aside: what their library lists
   *  unfiltered. Absent on a view stored before the friends list showed it. */
  bookCount?: number
  favoriteCount: number
  readingCount: number
  toReadCount: number
  /** The book most recently started, for the friends list to name. */
  readingTitle?: BookTitle
  /** The hearted books, most recently touched first — what the Découvrir tab
   *  offers to the reader's friends. */
  favorites: SharedFavorite[]
  /** The books finished each year, in the reader's time zone, the years with
   *  none left out: what the friends' reading challenge ranks them by. Absent
   *  on a view stored before the challenge existed. */
  readPerYear?: YearCount[]
  /** What moved last on the shelf, one book per kind, in the order the friends
   *  list draws them. Undated by any window: how recent is recent is the
   *  screen's call, so the view does not go stale with the calendar. Absent on
   *  a view stored before the friends list showed it. */
  recentActivity?: SharedActivity[]
}

/** What happened to a book lately: picked up or read on, finished, hearted,
 *  shelved, or dropped. */
export type SharedActivityKind = 'reading' | 'read' | 'hearted' | 'added' | 'dropped'

/** One book that moved, with the day it did. */
export type SharedActivity = {
  kind: SharedActivityKind
  at: Date
  book: SharedFavorite
}

/** The shared shelf read against today: the challenge's figure is derived at
 *  read time, as every figure that depends on the calendar. */
export type SharedShelfToday = SharedShelf & {
  /** Books finished since January 1st, in the reader's own time zone. */
  readThisYear: number
}

/** A book as a friend's screen draws it from the stored view: a hearted one on
 *  the Découvrir tab, one that moved lately on the friends list. */
export type SharedFavorite = {
  id: BookId
  title: BookTitle
  authors: AuthorName[]
  format: BookFormat
  language?: BookLanguage
  series?: SeriesMembership
  coverPath?: ObjectPath
  publishedCoverUrl?: CoverUrl
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
  lastFinished?: Card
  booksRead: Trend
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

/** What the reader's books say about their tastes, genre by genre: the page the
 *  dashboard's genre card opens. Worked out from the library on each read rather
 *  than stored — the page is opened far less often than the dashboard, and a
 *  materialized copy would go stale with every write for nobody. */
export type GenreInsights = {
  /** Every book finished, with or without a genre. */
  readCount: number
  /** The genres of the finished books, the most read first. `other` and books
   *  without a genre are left out: they say nothing of a taste. */
  shares: GenreShare[]
  /** The formats of the finished books, the most read first. */
  formats: FormatShare[]
  /** The genres with enough rated books to be placed on the taste map. */
  tastes: GenreTaste[]
  /** The average of every rated finished book: what splits the taste map. */
  averageRating?: number
  /** The genre read little and liked well above the reader's average. */
  hiddenGem?: Genre
  longest?: { genre: Genre; averagePages: number }
  fastest?: { genre: Genre; averageDays: number }
  mostDropped?: { genre: Genre; droppedCount: number; startedCount: number }
  /** The genres of the closed list never finished, `other` aside, those with
   *  books waiting on the pile first. */
  unexplored: UnexploredGenre[]
}

export type GenreShare = { genre: Genre; count: number }
export type FormatShare = { format: BookFormat; count: number; topGenre?: Genre }
export type GenreTaste = { genre: Genre; readCount: number; averageRating: number }
export type UnexploredGenre = { genre: Genre; pileCount: number }
