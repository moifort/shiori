import { LocalDate } from '~/domain/analytics/primitives'
import type {
  AnalyticsView,
  BookCard,
  Dashboard,
  Finish,
  FormatShare,
  GenreCount,
  GenreInsights,
  GenreShare,
  GenreTaste,
  MonthHours,
  MonthPages,
  SeriesProgress,
  SharedFavorite,
  SharedShelf,
  SharedShelfToday,
  TimeZone,
  Trend,
  YearCount,
} from '~/domain/analytics/types'
import {
  coverSourcesOf,
  listeningProgressOf,
  readVolumeNumbersOf,
  seriesRatingsOf,
  shelfDateOf,
  shelvedOf,
  shownRatingOf,
} from '~/domain/book/business-rules'
import type { Book, BookFormat, Genre, StarRating, Subgenre } from '~/domain/book/types'
import { GENRES } from '~/domain/book/types'
import { recentActivityOf } from '~/domain/friendship/business-rules'
import {
  followedSagasOf,
  followedStateOf,
  inTabOrder,
  progressOf,
} from '~/domain/series/business-rules'
import { catalogueKeyOf } from '~/domain/series/primitives'
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
const SERIES_SHOWN = 6
const TOP_GENRES = 4

/** Bumped whenever the view gains a figure or a rule changes, so a view stored
 *  by an older bundle is rebuilt on its next read instead of answering with a
 *  field it never computed. */
export const VIEW_VERSION = 15

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
    format: book.format,
    ...coverSourcesOf(book),
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
    shared: sharedShelfOf(books, timeZone),
  }
}

/** How many hearted books a friend's Découvrir tab can draw from one shelf. */
const SHARED_FAVORITES_KEPT = 30

const sharedBookOf = (book: Book): SharedFavorite => ({
  id: book.id,
  title: book.title,
  authors: book.authors,
  format: book.format,
  language: book.language,
  series: book.series,
  ...coverSourcesOf(book),
})

/** The shelf as a friend sees it: the books marked "do not share" are dropped
 *  first, so no count and no title here can betray them. */
export const sharedShelfOf = (books: readonly Book[], timeZone: TimeZone): SharedShelf => {
  const shown = books.filter((book) => !book.hidden)
  const reading = shelvedOf(shown.filter((book) => book.status === 'reading'))
  const favorites = shown
    .filter((book) => book.favorite === true)
    .sort(
      (left, right) =>
        (right.updatedAt ?? right.addedAt).getTime() - (left.updatedAt ?? left.addedAt).getTime(),
    )
  return {
    bookCount: shown.filter((book) => book.status !== 'dropped').length,
    favoriteCount: favorites.length,
    readingCount: reading.length,
    toReadCount: shown.filter((book) => book.status === 'to-read').length,
    readingTitle: reading[0]?.title,
    favorites: favorites.slice(0, SHARED_FAVORITES_KEPT).map(sharedBookOf),
    readPerYear: readPerYearOf(shown, timeZone),
    recentActivity: recentActivityOf(shown).map(({ kind, at, book }) => ({
      kind,
      at,
      book: sharedBookOf(book),
    })),
  }
}

/** How many books were finished each year, oldest year first, the years with
 *  none left out. */
export const readPerYearOf = (books: readonly Book[], timeZone: TimeZone): YearCount[] => {
  const counts = new Map<number, number>()
  for (const book of books) {
    if (book.status !== 'read' || book.finishedAt === undefined) continue
    const year = yearOf(localDateOf(book.finishedAt, timeZone))
    counts.set(year, (counts.get(year) ?? 0) + 1)
  }
  return [...counts]
    .sort(([left], [right]) => left - right)
    .map(([year, count]) => ({ year, count }))
}

/** The shared shelf read against the reader's today. */
export const sharedShelfTodayOf = (shelf: SharedShelf, today: LocalDateValue): SharedShelfToday => {
  const currentYear = yearOf(today)
  return {
    ...shelf,
    readThisYear: shelf.readPerYear?.find((entry) => entry.year === currentYear)?.count ?? 0,
  }
}

/** The sagas the Series tab lists as in progress, measured on their published
 *  spine as the saga screen measures them. Drawn from the tab's own rows — one
 *  per saga and edition, in the state the tab gives it, dated on that
 *  edition's books — so the card reads as the top of the tab filtered on
 *  "in progress". A saga with no catalogue, or no numbered volume, has nothing
 *  to measure against and is left out. A saga held in progress in two editions
 *  shows once, as its most recently shelved edition: the card opens the saga,
 *  not an edition. */
export const seriesProgressOf = (
  books: readonly Book[],
  catalogues: readonly Series[],
  currentYear: number,
  seriesRatings: ReadonlyMap<SeriesId, StarRating> = new Map(),
  hearted: ReadonlySet<SeriesId> = new Set(),
): SeriesProgress[] => {
  const catalogueOf = new Map(
    catalogues.map((series) => [catalogueKeyOf(series.id, series.language), series]),
  )
  const sagas = followedSagasOf(books).map((saga) => ({
    ...saga,
    shelvedAt: new Date(Math.max(...saga.books.map((book) => shelfDateOf(book).getTime()))),
  }))
  const progress: SeriesProgress[] = []
  for (const saga of inTabOrder(sagas)) {
    const series = catalogueOf.get(catalogueKeyOf(saga.id, saga.language))
    if (!series || progress.some((shown) => shown.id === saga.id)) continue
    const read = readVolumeNumbersOf(saga.books)
    const edition = { language: saga.language }
    const state = followedStateOf(
      saga.books.map((book) => book.status),
      series,
      read,
      Year(currentYear),
      false,
      edition,
    )
    if (state !== 'in-progress') continue
    const measured = progressOf(series, read, Year(currentYear), edition)
    if (!measured) continue
    progress.push({
      id: series.id,
      name: series.name,
      readCount: measured.readCount,
      totalCount: measured.totalCount,
      rating: sagaRatingOf(series.id, saga.books, seriesRatings),
      favorite: hearted.has(series.id),
      lastActivityAt: saga.shelvedAt,
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

// The Series tab's order, so the card reads as the top of that tab: the saga
// whose latest volume was shelved most recently first, then by name.
const compareSeriesProgress = (left: SeriesProgress, right: SeriesProgress): number =>
  right.lastActivityAt.getTime() - left.lastActivityAt.getTime() ||
  (left.name < right.name ? -1 : left.name > right.name ? 1 : 0)

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
    lastFinished: view.lastFinished,
    booksRead: booksReadTrendOf(finishes, today),
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

const finishedWithin = (finishes: readonly Finish[], { from, to }: { from: number; to: number }) =>
  finishes.filter((finish) => {
    const day = dayNumberOf(finish.finishedOn)
    return day >= from && day <= to
  })

/** Books finished this year to date, against the same span of last year. No
 *  comparison when last year finished nothing at all: a reader who started in
 *  the spring would otherwise see a rise from zero. */
export const booksReadTrendOf = (finishes: readonly Finish[], today: LocalDateValue): Trend => {
  const current = finishedWithin(finishes, currentSpanOf(today)).length
  const previousYear = yearOf(today) - 1
  const lastYearFinished = finishes.some((finish) => yearOf(finish.finishedOn) === previousYear)
  return {
    current: current > 0 ? current : undefined,
    previous: lastYearFinished ? finishedWithin(finishes, previousSpanOf(today)).length : undefined,
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

/** Below this many books a genre's figure is luck rather than taste: it is
 *  placed on no map and holds no record. */
export const ENOUGH_BOOKS = 3

/** How far above the reader's own average a genre read little must be rated to
 *  be worth pointing out. */
export const GEM_MARGIN = 0.5

/** How many subgenres the taste map places apart, the most read: past it, a
 *  large library's subgenres crowd the map into unreadable names. */
export const MAP_SUBGENRES = 6

/** How many places the taste map draws, the most read, the gem always among
 *  them. */
export const MAP_PLACES = 10

const DAY = 86_400_000

/** What the reader's books say about their tastes, genre by genre. Read books
 *  for every figure but two: the dropped record counts every book started, and
 *  the unexplored genres count the pile. */
export const genreInsightsOf = (books: readonly Book[]): GenreInsights => {
  const read = books.filter(({ status }) => status === 'read')
  const readByGenre = byGenre(read)
  const shares = [...readByGenre]
    .map(([genre, shelf]) => ({ genre, count: shelf.length }))
    .sort(mostFirst)
  const averageRating = meanOf(read.flatMap(ratingOf))
  const tastes = [...readByGenre]
    .flatMap(([genre, shelf]) => tasteOf(genre, shelf))
    .sort(mostReadFirst)
  const tasteMap = tasteMapOf(read)
  const gem = hiddenGemOf(tasteMap, averageRating)
  return {
    readCount: read.length,
    shares,
    formats: formatSharesOf(read),
    tastes,
    tasteMap: drawnOf(tasteMap, gem),
    averageRating,
    hiddenGem: hiddenGemOf(tastes, averageRating)?.genre,
    gem,
    longest: longestOf(readByGenre),
    fastest: fastestOf(readByGenre),
    mostDropped: mostDroppedOf(books),
    unexplored: GENRES.filter((genre) => genre !== 'other' && !readByGenre.has(genre))
      .map((genre) => ({
        genre,
        pileCount: books.filter((book) => book.status === 'to-read' && book.genre === genre).length,
      }))
      .sort((left, right) => right.pileCount - left.pileCount),
  }
}

/** The formats read, each with the genre it carries most. */
const formatSharesOf = (read: readonly Book[]): FormatShare[] => {
  const byFormat = new Map<BookFormat, Book[]>()
  for (const book of read) byFormat.set(book.format, [...(byFormat.get(book.format) ?? []), book])
  return [...byFormat]
    .map(([format, shelf]) => {
      const [top] = [...byGenre(shelf)]
        .map(([genre, books]) => ({ genre, count: books.length }))
        .sort(mostFirst)
      return { format, count: shelf.length, topGenre: top?.genre }
    })
    .sort((left, right) => right.count - left.count || left.format.localeCompare(right.format))
}

/** The taste map: a book goes to its head subgenre — the most representative
 *  — when that subgenre gathers enough rated books of the genre on its own and
 *  is among the most read of them, and to its genre otherwise. A small library
 *  reads as genres only; a large one brings out the subgenres that weigh.
 *  Labels meet whatever their case or hyphens ("Space-opera", "space opera");
 *  across languages they do not. */
const tasteMapOf = (read: readonly Book[]): GenreTaste[] => {
  const bySubgenre = new Map<string, { genre: Genre; subgenre: Subgenre; books: Book[] }>()
  for (const book of read) {
    const [head] = book.subgenres
    if (!head || book.genre === undefined || book.genre === 'other') continue
    const key = `${book.genre}~${subgenreKeyOf(head.label)}`
    const entry = bySubgenre.get(key) ?? { genre: book.genre, subgenre: head.label, books: [] }
    bySubgenre.set(key, { ...entry, books: [...entry.books, book] })
  }
  const subgenreTastes = [...bySubgenre.values()]
    .flatMap(({ genre, subgenre, books }) => tasteOf(genre, books, subgenre))
    .sort(mostReadFirst)
    .slice(0, MAP_SUBGENRES)
  const claimed = new Set(
    [...bySubgenre.values()]
      .filter(({ genre, subgenre }) =>
        subgenreTastes.some((taste) => taste.genre === genre && taste.subgenre === subgenre),
      )
      .flatMap(({ books }) => books.map(({ id }) => id)),
  )
  const genreTastes = [...byGenre(read.filter(({ id }) => !claimed.has(id)))].flatMap(
    ([genre, shelf]) => tasteOf(genre, shelf),
  )
  return [...subgenreTastes, ...genreTastes].sort(mostReadFirst)
}

/** The places the map draws: the most read, the gem taking the last seat when
 *  it would miss out, so the callout never names a bubble that is not there. */
const drawnOf = (tasteMap: readonly GenreTaste[], gem: GenreTaste | undefined): GenreTaste[] => {
  const drawn = tasteMap.slice(0, MAP_PLACES)
  return gem === undefined || drawn.includes(gem) ? drawn : [...drawn.slice(0, -1), gem]
}

/** The key two spellings of one subgenre share: case and hyphens aside. */
export const subgenreKeyOf = (label: string): string =>
  label
    .toLocaleLowerCase('fr')
    .replace(/[\s\-‐‑–]+/gu, ' ')
    .trim()

/** A place on the map for these books, when enough of them are rated. */
const tasteOf = (genre: Genre, books: readonly Book[], subgenre?: Subgenre): GenreTaste[] => {
  const ratings = books.flatMap(ratingOf)
  return ratings.length < ENOUGH_BOOKS
    ? []
    : [{ genre, subgenre, readCount: books.length, averageRating: meanOf(ratings) ?? 0 }]
}

const mostReadFirst = (left: GenreTaste, right: GenreTaste) =>
  right.readCount - left.readCount ||
  genreOrder(left, right) ||
  (left.subgenre ?? '').localeCompare(right.subgenre ?? '')

/** The place left of the median that the reader rates well above their own
 *  average: few books, much liked. The best rated wins, then the least read. */
export const hiddenGemOf = (
  tastes: readonly GenreTaste[],
  averageRating: number | undefined,
): GenreTaste | undefined => {
  if (averageRating === undefined || tastes.length < 3) return undefined
  const median = medianOf(tastes.map(({ readCount }) => readCount))
  const [gem] = tastes
    .filter(
      ({ readCount, averageRating: rating }) =>
        readCount < median && rating >= averageRating + GEM_MARGIN,
    )
    .sort(
      (left, right) => right.averageRating - left.averageRating || left.readCount - right.readCount,
    )
  return gem
}

const longestOf = (readByGenre: Map<Genre, Book[]>) => {
  const [longest] = [...readByGenre]
    .flatMap(([genre, shelf]) => {
      const pages = shelf.flatMap(({ pageCount }) => (pageCount === undefined ? [] : [pageCount]))
      return pages.length < ENOUGH_BOOKS
        ? []
        : [{ genre, averagePages: Math.round(pages.reduce((sum, p) => sum + p, 0) / pages.length) }]
    })
    .sort((left, right) => right.averagePages - left.averagePages || genreOrder(left, right))
  return longest
}

/** Days from the first page to the last, a book read within the day counting
 *  one. */
const fastestOf = (readByGenre: Map<Genre, Book[]>) => {
  const [fastest] = [...readByGenre]
    .flatMap(([genre, shelf]) => {
      const days = shelf.flatMap(({ startedAt, finishedAt }) =>
        startedAt && finishedAt
          ? [Math.max(1, Math.round((finishedAt.getTime() - startedAt.getTime()) / DAY))]
          : [],
      )
      return days.length < ENOUGH_BOOKS
        ? []
        : [{ genre, averageDays: Math.round(days.reduce((sum, d) => sum + d, 0) / days.length) }]
    })
    .sort((left, right) => left.averageDays - right.averageDays || genreOrder(left, right))
  return fastest
}

/** The genre given up most often, out of the books of it ever opened: read,
 *  being read or dropped. */
const mostDroppedOf = (books: readonly Book[]) => {
  const opened = books.filter(({ status }) => status !== 'to-read')
  const [dropped] = [...byGenre(opened)]
    .flatMap(([genre, shelf]) => {
      const droppedCount = shelf.filter(({ status }) => status === 'dropped').length
      return droppedCount === 0 || shelf.length < ENOUGH_BOOKS
        ? []
        : [{ genre, droppedCount, startedCount: shelf.length }]
    })
    .sort(
      (left, right) =>
        right.droppedCount / right.startedCount - left.droppedCount / left.startedCount ||
        right.droppedCount - left.droppedCount ||
        genreOrder(left, right),
    )
  return dropped
}

/** The books of each genre, `other` and books without one left out. */
const byGenre = (books: readonly Book[]): Map<Genre, Book[]> => {
  const shelves = new Map<Genre, Book[]>()
  for (const book of books) {
    if (book.genre === undefined || book.genre === 'other') continue
    shelves.set(book.genre, [...(shelves.get(book.genre) ?? []), book])
  }
  return shelves
}

const ratingOf = ({ rating }: Book): number[] => (rating === undefined ? [] : [Number(rating)])

const meanOf = (values: readonly number[]): number | undefined =>
  values.length === 0
    ? undefined
    : Math.round((values.reduce((sum, value) => sum + value, 0) / values.length) * 10) / 10

export const medianOf = (values: readonly number[]): number => {
  const sorted = [...values].sort((left, right) => left - right)
  const middle = Math.floor(sorted.length / 2)
  return sorted.length % 2 === 0 ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
}

const genreOrder = (left: { genre: Genre }, right: { genre: Genre }) =>
  GENRES.indexOf(left.genre) - GENRES.indexOf(right.genre)

const mostFirst = (left: GenreShare, right: GenreShare) =>
  right.count - left.count || genreOrder(left, right)
