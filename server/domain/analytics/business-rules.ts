import { LocalDate } from '~/domain/analytics/primitives'
import type {
  AnalyticsView,
  BookCard,
  Dashboard,
  Finish,
  GenreCount,
  MonthHours,
  MonthPages,
  SeriesProgress,
  TimeZone,
  Trend,
  YearCount,
} from '~/domain/analytics/types'
import {
  listeningProgressOf,
  readVolumeNumbersOf,
  seriesRatingsOf,
  shelvedOf,
  shownRatingOf,
} from '~/domain/book/business-rules'
import type { Book, Genre, StarRating } from '~/domain/book/types'
import { progressOf, stateOf } from '~/domain/series/business-rules'
import type { Series, SeriesId } from '~/domain/series/types'
import { editionUnfollowed } from '~/domain/series-opinion/business-rules'
import type { SeriesOpinion } from '~/domain/series-opinion/types'
import { Year } from '~/domain/shared/primitives'
import type { UserId } from '~/domain/shared/types'
import type { LocalDate as LocalDateValue } from './types'

/** How many years the books chart shows, always: past six bars they stop being
 *  readable on a phone, and fewer leaves one wide bar for a reader's first year. */
const YEARS_SHOWN = 9
const READING_SHOWN = 10
const SUGGESTIONS_SHOWN = 6
const SERIES_SHOWN = 6
const TOP_GENRES = 4

/** Bumped whenever the view gains a figure or a rule changes, so a view stored
 *  by an older bundle is rebuilt on its next read instead of answering with a
 *  field it never computed. */
export const VIEW_VERSION = 7

// MARK: - Calendar

const DAY_MS = 86_400_000

/** The calendar day an instant falls on for a reader in `timeZone`. */
export const localDateOf = (instant: Date, timeZone: TimeZone): LocalDateValue => {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(instant)
  const part = (type: string) => parts.find((entry) => entry.type === type)?.value ?? ''
  return LocalDate(`${part('year')}-${part('month')}-${part('day')}`)
}

/** Days since the epoch, so that two local dates subtract into a day count with
 *  no daylight saving hour in between. */
const dayNumberOf = (date: LocalDateValue): number => {
  const [year, month, day] = date.split('-').map(Number)
  return Date.UTC(year, month - 1, day) / DAY_MS
}

const yearOf = (date: LocalDateValue): number => Number(date.slice(0, 4))

const dayNumberFrom = (year: number, month: number, day: number): number =>
  Date.UTC(year, month - 1, day) / DAY_MS

/** Days a reading lasted, both ends included: a book started and finished the
 *  same day was read in one day, not zero. */
export const daysToFinishOf = (finish: Pick<Finish, 'startedOn' | 'finishedOn'>): number =>
  dayNumberOf(finish.finishedOn) - dayNumberOf(finish.startedOn) + 1

// MARK: - Building the view

/** Rebuild the whole view from the reader's books and the catalogues of the sagas
 *  they own. Pure: the command around it does the reads and the write. */
export const analyticsViewOf = (input: {
  userId: UserId
  books: readonly Book[]
  catalogues: readonly Series[]
  /** What the reader makes of their sagas: the hearts are counted, and a saga's
   *  rating stands in for every volume of it the reader left unrated. */
  opinions?: readonly SeriesOpinion[]
  timeZone: TimeZone
  now: Date
}): AnalyticsView => {
  const { userId, books, catalogues, opinions = [], timeZone, now } = input
  const finished = books.filter(
    (book): book is Book & { finishedAt: Date } =>
      book.status === 'read' && book.finishedAt !== undefined,
  )

  // What the statistics count is what the reader sees on the book: a saga
  // rated as a whole rates each of its unrated volumes, once per volume.
  const seriesRatings = seriesRatingsOf(opinions)
  // An edition set aside is not one the reader is working through: its volumes
  // leave the progress bars, and a saga with no edition left leaves them too.
  const opinionOf = new Map(opinions.map((opinion) => [opinion.seriesId, opinion]))
  const followedBooks = books.filter(
    (book) =>
      book.series === undefined || !editionUnfollowed(opinionOf.get(book.series.id), book.language),
  )
  const ratingOf = (book: Book) => shownRatingOf(book, seriesRatings)
  const cardOf = (book: Book): BookCard => ({
    id: book.id,
    title: book.title,
    authors: book.authors,
    coverPath: book.coverPath,
    publishedCoverUrl: book.publishedCoverUrl,
    rating: ratingOf(book),
    listeningProgress: listeningProgressOf(book),
    startedAt: book.startedAt,
    finishedAt: book.finishedAt,
  })

  const finishes = finished.map((book): Finish => {
    const finishedOn = localDateOf(book.finishedAt, timeZone)
    const startedOn = localDateOf(book.startedAt ?? book.finishedAt, timeZone)
    return {
      bookId: book.id,
      // A start recorded after the finish is a clock oddity, not a negative reading.
      startedOn: startedOn > finishedOn ? finishedOn : startedOn,
      finishedOn,
      pageCount: book.pageCount,
      durationMinutes: book.durationMinutes,
      genre: book.genre,
      rating: ratingOf(book),
    }
  })

  // Shelved as the Library tab shelves them, so the first cover of the
  // dashboard is the first row of the library.
  const reading = shelvedOf(books.filter((book) => book.status === 'reading')).map(cardOf)

  const toRead = books
    .filter((book) => book.status === 'to-read')
    .sort((left, right) => right.addedAt.getTime() - left.addedAt.getTime())
    .map(cardOf)

  const last = [...finished].sort(
    (left, right) => right.finishedAt.getTime() - left.finishedAt.getTime(),
  )[0]

  return {
    userId,
    timeZone,
    version: VIEW_VERSION,
    stale: false,
    refreshedAt: now,
    finishes,
    reading,
    toRead,
    lastFinished: last ? cardOf(last) : undefined,
    series: seriesProgressOf(
      followedBooks,
      catalogues,
      yearOf(localDateOf(now, timeZone)),
      seriesRatings,
      new Set(opinions.filter((opinion) => opinion.favorite).map((opinion) => opinion.seriesId)),
    ),
    favoriteBookCount: books.filter((book) => book.favorite === true).length,
    favoriteSeriesCount: opinions.filter((opinion) => opinion.favorite === true).length,
    audiobookCount: books.filter((book) => book.format === 'audiobook').length,
    printedBookCount: books.filter((book) => book.format !== 'audiobook').length,
    droppedCount: books.filter((book) => book.status === 'dropped').length,
  }
}

/** The sagas still in progress, measured on their published spine as the saga
 *  screen measures them. A saga with no catalogue, or no numbered volume, has
 *  nothing to measure against and is left out. */
export const seriesProgressOf = (
  books: readonly Book[],
  catalogues: readonly Series[],
  currentYear: number,
  seriesRatings: ReadonlyMap<SeriesId, StarRating> = new Map(),
  hearted: ReadonlySet<SeriesId> = new Set(),
): SeriesProgress[] => {
  const progress: SeriesProgress[] = []
  for (const series of catalogues) {
    const owned = books.filter((book) => book.series?.id === series.id)
    if (owned.length === 0) continue
    const read = readVolumeNumbersOf(owned)
    // The saga's own state and ring: a saga the Series tab calls finished is
    // not one the dashboard still counts as in progress.
    if (stateOf(series, read, Year(currentYear)) !== 'in-progress') continue
    const measured = progressOf(series, read, Year(currentYear))
    if (!measured) continue
    const { readCount, totalCount } = measured
    progress.push({
      id: series.id,
      name: series.name,
      readCount,
      totalCount,
      rating: sagaRatingOf(series.id, owned, seriesRatings),
      favorite: hearted.has(series.id),
      lastActivityAt: new Date(
        Math.max(
          ...owned.map((book) => (book.finishedAt ?? book.startedAt ?? book.addedAt).getTime()),
        ),
      ),
    })
  }
  return progress
}

/** What the reader thinks of a saga, for ranking the sagas in progress: their
 *  own rating of it, else the average of the volumes they rated themselves.
 *  Undefined when they have said nothing of it. */
const sagaRatingOf = (
  seriesId: SeriesId,
  owned: readonly Book[],
  seriesRatings: ReadonlyMap<SeriesId, StarRating>,
): number | undefined => {
  const own = seriesRatings.get(seriesId)
  if (own !== undefined) return own
  const rated = owned.flatMap((book) => (book.rating === undefined ? [] : [book.rating]))
  return rated.length === 0
    ? undefined
    : rated.reduce((sum, rating) => sum + rating, 0) / rated.length
}

// The best rated first, an unrated saga after every rated one, and the most
// recent activity among equals.
const compareSeriesProgress = (left: SeriesProgress, right: SeriesProgress): number =>
  (right.rating ?? 0) - (left.rating ?? 0) ||
  right.lastActivityAt.getTime() - left.lastActivityAt.getTime()

// MARK: - Reading the view against today

export const dashboardOf = (view: AnalyticsView, today: LocalDateValue): Dashboard<BookCard> => {
  const currentYear = yearOf(today)
  const { finishes } = view

  return {
    currentYear,
    booksPerYear: booksPerYearOf(finishes, currentYear),
    pagesPerMonth: pagesPerMonthOf(finishes, currentYear),
    hoursPerMonth: hoursPerMonthOf(finishes, currentYear),
    reading: view.reading.slice(0, READING_SHOWN),
    suggestions: shuffled(view.toRead, `${view.userId}:${today}`).slice(0, SUGGESTIONS_SHOWN),
    lastFinished: view.lastFinished,
    pagesPerDay: pagesPerDayTrendOf(finishes, today),
    daysToFinish: daysToFinishTrendOf(finishes, today),
    toReadCount: view.toRead.length,
    readCount: finishes.length,
    monthsToClearPile: monthsToClearPileOf(finishes, view.toRead.length, today),
    averageRating: averageRatingOf(finishes),
    ratedCount: finishes.filter((finish) => finish.rating !== undefined).length,
    genres: genresOf(finishes),
    // A view stored before the heart was carried reads as no heart.
    series: [...view.series]
      .sort(compareSeriesProgress)
      .slice(0, SERIES_SHOWN)
      .map((series) => ({ ...series, favorite: series.favorite ?? false })),
    favoriteCount: (view.favoriteBookCount ?? 0) + (view.favoriteSeriesCount ?? 0),
    hasAudiobooks: (view.audiobookCount ?? 0) > 0,
    hasPrintedBooks: view.printedBookCount === undefined || view.printedBookCount > 0,
    droppedCount: view.droppedCount ?? 0,
    libraryIsEmpty: finishes.length === 0 && view.reading.length === 0 && view.toRead.length === 0,
  }
}

/** Books finished per year over the last nine years, this one included, empty
 *  years at zero. Always nine bars: a reader's first year alone would be one wide
 *  bar, and the empty years beside it show where the chart is going. Nine rather
 *  than a handful because the card is as wide either way, and six bars left it
 *  looking half empty. */
export const booksPerYearOf = (finishes: readonly Finish[], currentYear: number): YearCount[] => {
  const counts = new Map<number, number>()
  for (const finish of finishes) {
    const year = yearOf(finish.finishedOn)
    counts.set(year, (counts.get(year) ?? 0) + 1)
  }
  return Array.from({ length: YEARS_SHOWN }, (_, index) => {
    const year = currentYear - YEARS_SHOWN + 1 + index
    return { year, count: counts.get(year) ?? 0 }
  })
}

/** Pages a set of finished books puts on the days from `from` to `to` inclusive.
 *
 *  Progress is never tracked, so each book spreads its page count evenly over the
 *  days it was open. Honest without asking the reader for a page number every
 *  evening; a book started in December and finished in January counts on both
 *  years. Books without a page count put nothing anywhere. */
export const pagesBetween = (finishes: readonly Finish[], from: number, to: number): number => {
  let pages = 0
  for (const finish of finishes) {
    if (finish.pageCount === undefined) continue
    const start = dayNumberOf(finish.startedOn)
    const end = dayNumberOf(finish.finishedOn)
    const overlap = Math.min(end, to) - Math.max(start, from) + 1
    if (overlap > 0) pages += (Number(finish.pageCount) * overlap) / (end - start + 1)
  }
  return pages
}

export const pagesPerMonthOf = (finishes: readonly Finish[], year: number): MonthPages[] =>
  Array.from({ length: 12 }, (_, index) => {
    const month = index + 1
    const from = dayNumberFrom(year, month, 1)
    const to = dayNumberFrom(year, month + 1, 1) - 1
    return { month, pages: Math.round(pagesBetween(finishes, from, to)) }
  })

/** Minutes a set of finished audiobooks puts on the days from `from` to `to`
 *  inclusive, spread evenly over the days each one was open — the same honest
 *  guess `pagesBetween` makes, for the same reason: listening progress is never
 *  tracked either. A book with no running time puts nothing anywhere, which
 *  leaves every printed book out of the count on its own. */
export const minutesListenedBetween = (
  finishes: readonly Finish[],
  from: number,
  to: number,
): number => {
  let minutes = 0
  for (const finish of finishes) {
    if (finish.durationMinutes === undefined) continue
    const start = dayNumberOf(finish.startedOn)
    const end = dayNumberOf(finish.finishedOn)
    const overlap = Math.min(end, to) - Math.max(start, from) + 1
    if (overlap > 0) minutes += (Number(finish.durationMinutes) * overlap) / (end - start + 1)
  }
  return minutes
}

/** Hours listened per month of the given year, rounded to the hour. Rounded on
 *  purpose: a bar labelled "12" reads at a glance where "12,4" reads as noise,
 *  and a month under half an hour is closer to nothing than to an hour. */
export const hoursPerMonthOf = (finishes: readonly Finish[], year: number): MonthHours[] =>
  Array.from({ length: 12 }, (_, index) => {
    const month = index + 1
    const from = dayNumberFrom(year, month, 1)
    const to = dayNumberFrom(year, month + 1, 1) - 1
    return { month, hours: Math.round(minutesListenedBetween(finishes, from, to) / 60) }
  })

/** The same span of last year: January 1st to today's date one year earlier. A
 *  February 29th maps onto March 1st, which Date.UTC rolls over to on its own. */
const previousSpanOf = (today: LocalDateValue) => {
  const [year, month, day] = today.split('-').map(Number)
  return { from: dayNumberFrom(year - 1, 1, 1), to: dayNumberFrom(year - 1, month, day) }
}

const currentSpanOf = (today: LocalDateValue) => ({
  from: dayNumberFrom(yearOf(today), 1, 1),
  to: dayNumberOf(today),
})

export const pagesPerDayTrendOf = (finishes: readonly Finish[], today: LocalDateValue): Trend => {
  if (!finishes.some((finish) => finish.pageCount !== undefined)) return {}
  const current = currentSpanOf(today)
  const previous = previousSpanOf(today)
  const perDay = ({ from, to }: { from: number; to: number }) =>
    Math.round(pagesBetween(finishes, from, to) / (to - from + 1))
  const previousYear = yearOf(today) - 1
  const lastYearHasPages =
    pagesBetween(finishes, dayNumberFrom(previousYear, 1, 1), dayNumberFrom(previousYear, 12, 31)) >
    0
  return {
    current: perDay(current),
    previous: lastYearHasPages ? perDay(previous) : undefined,
  }
}

/** Median rather than mean: one book left open for six months would drag a mean
 *  far from how long the reader usually takes. */
export const medianOf = (values: readonly number[]): number | undefined => {
  if (values.length === 0) return undefined
  const sorted = [...values].sort((left, right) => left - right)
  const middle = Math.floor(sorted.length / 2)
  return sorted.length % 2 === 1
    ? sorted[middle]
    : Math.round((sorted[middle - 1] + sorted[middle]) / 2)
}

export const daysToFinishTrendOf = (finishes: readonly Finish[], today: LocalDateValue): Trend => {
  const within = ({ from, to }: { from: number; to: number }) =>
    finishes
      .filter((finish) => {
        const day = dayNumberOf(finish.finishedOn)
        return day >= from && day <= to
      })
      .map(daysToFinishOf)
  return {
    current: medianOf(within(currentSpanOf(today))),
    previous: medianOf(within(previousSpanOf(today))),
  }
}

/** How long the pile would last at the pace of the last twelve months. Absent when
 *  there is no pile, or no pace to divide it by. */
export const monthsToClearPileOf = (
  finishes: readonly Finish[],
  pileSize: number,
  today: LocalDateValue,
): number | undefined => {
  const end = dayNumberOf(today)
  const finishedLastYear = finishes.filter((finish) => {
    const day = dayNumberOf(finish.finishedOn)
    return day > end - 365 && day <= end
  }).length
  if (pileSize === 0 || finishedLastYear === 0) return undefined
  return Math.ceil(pileSize / (finishedLastYear / 12))
}

export const averageRatingOf = (finishes: readonly Finish[]): number | undefined => {
  const ratings = finishes.flatMap((finish) =>
    finish.rating === undefined ? [] : [Number(finish.rating)],
  )
  if (ratings.length === 0) return undefined
  return Math.round((ratings.reduce((sum, rating) => sum + rating, 0) / ratings.length) * 10) / 10
}

/** The genres of every book finished since the first: the four most read, then
 *  one "others" segment gathering the rest, books without a genre and `other`.
 *  Every year rather than this one: what the reader reads is a taste, and a
 *  January card holding two books says nothing about it. */
export const genresOf = (finishes: readonly Finish[]): GenreCount[] => {
  const counts = new Map<Genre, number>()
  for (const finish of finishes) {
    const genre = finish.genre ?? 'other'
    counts.set(genre, (counts.get(genre) ?? 0) + 1)
  }
  const ranked = [...counts.entries()]
    .filter(([genre]) => genre !== 'other')
    .sort(
      ([leftGenre, left], [rightGenre, right]) =>
        right - left || leftGenre.localeCompare(rightGenre),
    )
  const top = ranked.slice(0, TOP_GENRES).map(([genre, count]) => ({ genre, count }))
  const others =
    ranked.slice(TOP_GENRES).reduce((sum, [, count]) => sum + count, 0) + (counts.get('other') ?? 0)
  return others > 0 ? [...top, { count: others }] : top
}

/** A shuffle that gives the same order all day for the same seed, so the
 *  suggestions do not reshuffle on every pull to refresh, and a new one the next
 *  day. FNV-1a seeds a mulberry32 generator driving a Fisher–Yates pass. */
export const shuffled = <T>(items: readonly T[], seed: string): T[] => {
  let state = 2166136261
  for (let index = 0; index < seed.length; index += 1) {
    state ^= seed.charCodeAt(index)
    state = Math.imul(state, 16777619)
  }
  const random = () => {
    state = (state + 0x6d2b79f5) | 0
    let mixed = Math.imul(state ^ (state >>> 15), 1 | state)
    mixed = (mixed + Math.imul(mixed ^ (mixed >>> 7), 61 | mixed)) ^ mixed
    return ((mixed ^ (mixed >>> 14)) >>> 0) / 4294967296
  }
  const result = [...items]
  for (let index = result.length - 1; index > 0; index -= 1) {
    const other = Math.floor(random() * (index + 1))
    ;[result[index], result[other]] = [result[other], result[index]]
  }
  return result
}
