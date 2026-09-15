import { LocalDate } from '~/domain/analytics/primitives'
import type {
  AnalyticsView,
  BookCard,
  Dashboard,
  Finish,
  GenreCount,
  MonthPages,
  SeriesProgress,
  TimeZone,
  Trend,
  YearCount,
} from '~/domain/analytics/types'
import { readVolumeNumbersOf } from '~/domain/book/business-rules'
import type { Book, Genre } from '~/domain/book/types'
import { publishedVolumes, stateOf } from '~/domain/series/business-rules'
import type { Series } from '~/domain/series/types'
import { Year } from '~/domain/shared/primitives'
import type { UserId } from '~/domain/shared/types'
import type { LocalDate as LocalDateValue } from './types'

/** How many years the books chart reaches back. Past six bars they stop being
 *  readable on a phone, and a reader's first year of use says little anyway. */
const YEARS_SHOWN = 6
const READING_SHOWN = 10
const SUGGESTIONS_SHOWN = 6
const SERIES_SHOWN = 3
const TOP_GENRES = 4

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
  timeZone: TimeZone
  now: Date
}): AnalyticsView => {
  const { userId, books, catalogues, timeZone, now } = input
  const finished = books.filter(
    (book): book is Book & { finishedAt: Date } =>
      book.status === 'read' && book.finishedAt !== undefined,
  )

  const finishes = finished.map((book): Finish => {
    const finishedOn = localDateOf(book.finishedAt, timeZone)
    const startedOn = localDateOf(book.startedAt ?? book.finishedAt, timeZone)
    return {
      bookId: book.id,
      // A start recorded after the finish is a clock oddity, not a negative reading.
      startedOn: startedOn > finishedOn ? finishedOn : startedOn,
      finishedOn,
      pageCount: book.pageCount,
      genre: book.genre,
      rating: book.rating,
    }
  })

  const reading = books
    .filter((book) => book.status === 'reading')
    .sort(
      (left, right) =>
        (right.startedAt ?? right.addedAt).getTime() - (left.startedAt ?? left.addedAt).getTime(),
    )
    .map(cardOf)

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
    stale: false,
    refreshedAt: now,
    finishes,
    reading,
    toRead,
    lastFinished: last ? cardOf(last) : undefined,
    series: seriesProgressOf(books, catalogues, yearOf(localDateOf(now, timeZone))),
  }
}

const cardOf = (book: Book): BookCard => ({
  id: book.id,
  title: book.title,
  authors: book.authors,
  coverPath: book.coverPath,
  publishedCoverUrl: book.publishedCoverUrl,
  rating: book.rating,
  startedAt: book.startedAt,
  finishedAt: book.finishedAt,
})

/** The sagas still in progress, measured on the numbered spine of published
 *  volumes: related works and announced volumes would make a finished spine look
 *  unfinished. A saga with no catalogue, or no numbered volume, has nothing to
 *  measure against and is left out. */
export const seriesProgressOf = (
  books: readonly Book[],
  catalogues: readonly Series[],
  currentYear: number,
): SeriesProgress[] => {
  const progress: SeriesProgress[] = []
  for (const series of catalogues) {
    const owned = books.filter((book) => book.series?.id === series.id)
    if (owned.length === 0) continue
    const read = readVolumeNumbersOf(owned)
    if (stateOf(series, read, Year(currentYear)) !== 'in-progress') continue
    const spine = publishedVolumes(series, Year(currentYear)).filter(
      (volume) => volume.kind === 'main' && volume.number !== undefined,
    )
    const readCount = spine.filter((volume) => read.has(Number(volume.number))).length
    // A saga can stay in progress on an unread novella alone; a full bar there
    // would sit among the sagas still to finish and read as a bug.
    if (spine.length === 0 || readCount === spine.length) continue
    progress.push({
      id: series.id,
      name: series.name,
      readCount,
      totalCount: spine.length,
      lastActivityAt: new Date(
        Math.max(
          ...owned.map((book) => (book.finishedAt ?? book.startedAt ?? book.addedAt).getTime()),
        ),
      ),
    })
  }
  return progress
}

// MARK: - Reading the view against today

export const dashboardOf = (view: AnalyticsView, today: LocalDateValue): Dashboard<BookCard> => {
  const currentYear = yearOf(today)
  const { finishes } = view

  return {
    currentYear,
    booksPerYear: booksPerYearOf(finishes, currentYear),
    pagesPerMonth: pagesPerMonthOf(finishes, currentYear),
    reading: view.reading.slice(0, READING_SHOWN),
    suggestions: shuffled(view.toRead, `${view.userId}:${today}`).slice(0, SUGGESTIONS_SHOWN),
    lastFinished: view.lastFinished,
    pagesPerDay: pagesPerDayTrendOf(finishes, today),
    daysToFinish: daysToFinishTrendOf(finishes, today),
    toReadCount: view.toRead.length,
    monthsToClearPile: monthsToClearPileOf(finishes, view.toRead.length, today),
    averageRating: averageRatingOf(finishes),
    ratedCount: finishes.filter((finish) => finish.rating !== undefined).length,
    genres: genresOf(finishes, currentYear),
    series: [...view.series]
      .sort((left, right) => right.lastActivityAt.getTime() - left.lastActivityAt.getTime())
      .slice(0, SERIES_SHOWN),
    libraryIsEmpty: finishes.length === 0 && view.reading.length === 0 && view.toRead.length === 0,
  }
}

/** Books finished per year, from the first finished book to this year, empty
 *  years included so the bars keep their spacing; the last six at most. Before
 *  any book is finished, this year alone at zero: the chart is drawn from the
 *  first book on, and a chart needs a bar to draw. */
export const booksPerYearOf = (finishes: readonly Finish[], currentYear: number): YearCount[] => {
  const counts = new Map<number, number>()
  for (const finish of finishes) {
    const year = yearOf(finish.finishedOn)
    counts.set(year, (counts.get(year) ?? 0) + 1)
  }
  const firstYear = Math.min(currentYear, ...counts.keys())
  const years: YearCount[] = []
  for (let year = firstYear; year <= currentYear; year += 1) {
    years.push({ year, count: counts.get(year) ?? 0 })
  }
  return years.slice(-YEARS_SHOWN)
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

/** The genres of the books finished this year: the four most read, then one
 *  "others" segment gathering the rest, books without a genre and `other`. */
export const genresOf = (finishes: readonly Finish[], currentYear: number): GenreCount[] => {
  const counts = new Map<Genre, number>()
  for (const finish of finishes) {
    if (yearOf(finish.finishedOn) !== currentYear) continue
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
