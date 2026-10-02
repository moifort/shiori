import { describe, expect, test } from 'bun:test'
import {
  analyticsViewOf,
  averageRatingOf,
  booksPerYearOf,
  booksReadTrendOf,
  dashboardOf,
  genreInsightsOf,
  genresOf,
  hiddenGemOf,
  hoursPerMonthOf,
  localDateOf,
  medianOf,
  monthsToClearPileOf,
  pagesPerMonthOf,
  readPerYearOf,
  seriesProgressOf,
  sharedShelfOf,
  sharedShelfTodayOf,
  subgenreKeyOf,
  VIEW_VERSION,
} from '~/domain/analytics/business-rules'
import { LocalDate, TimeZone } from '~/domain/analytics/primitives'
import type { Finish } from '~/domain/analytics/types'
import { BookId, ListeningMinutes, PageCount, StarRating, Subgenre } from '~/domain/book/primitives'
import type { Book, Genre } from '~/domain/book/types'
import { SeriesName, VolumeNumber } from '~/domain/series/primitives'
import type { Series, SeriesId } from '~/domain/series/types'
import { AuthorName, BookTitle, Year } from '~/domain/shared/primitives'
import type { UserId } from '~/domain/shared/types'

const paris = TimeZone('Europe/Paris')
const day = (value: string) => LocalDate(value)

const finish = (
  startedOn: string,
  finishedOn: string,
  extra: { pages?: number; minutes?: number; genre?: Genre; rating?: number } = {},
): Finish => ({
  bookId: BookId(`${startedOn}-${finishedOn}`),
  startedOn: day(startedOn),
  finishedOn: day(finishedOn),
  pageCount: extra.pages === undefined ? undefined : PageCount(extra.pages),
  durationMinutes: extra.minutes === undefined ? undefined : ListeningMinutes(extra.minutes),
  genre: extra.genre,
  rating: extra.rating === undefined ? undefined : StarRating(extra.rating),
})

describe('the calendar day of an instant', () => {
  // The whole reason the app sends its time zone.
  test('is taken in the reader time zone, not in UTC', () => {
    const newYearsEveLate = new Date('2025-12-31T23:30:00.000Z')

    expect(localDateOf(newYearsEveLate, TimeZone('UTC'))).toBe(day('2025-12-31'))
    expect(localDateOf(newYearsEveLate, paris)).toBe(day('2026-01-01'))
  })

  test('refuses a time zone the runtime does not know', () => {
    expect(() => TimeZone('Europe/Pariss')).toThrow()
  })
})

describe('books read per year', () => {
  test('counts the last nine years, empty years included', () => {
    const finishes = [finish('2023-02-01', '2023-02-10'), finish('2026-03-01', '2026-03-05')]

    expect(booksPerYearOf(finishes, 2026)).toEqual([
      { year: 2018, count: 0 },
      { year: 2019, count: 0 },
      { year: 2020, count: 0 },
      { year: 2021, count: 0 },
      { year: 2022, count: 0 },
      { year: 2023, count: 1 },
      { year: 2024, count: 0 },
      { year: 2025, count: 0 },
      { year: 2026, count: 1 },
    ])
  })

  test('leaves out a book finished before the last nine years', () => {
    const years = booksPerYearOf([finish('2015-01-01', '2015-01-02')], 2026)

    expect(years).toEqual(
      [2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025, 2026].map((year) => ({ year, count: 0 })),
    )
  })

  test('shows nine empty years before any book is finished', () => {
    expect(booksPerYearOf([], 2026).map(({ year }) => year)).toEqual([
      2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025, 2026,
    ])
  })
})

describe('pages read per month', () => {
  test('spreads a book evenly over the days it was open', () => {
    // 62 days, one page a day: 31 in March, 31 in April... minus April's 30.
    const pages = pagesPerMonthOf([finish('2026-03-01', '2026-05-01', { pages: 62 })], 2026)

    expect(pages.find(({ month }) => month === 3)?.pages).toBe(31)
    expect(pages.find(({ month }) => month === 4)?.pages).toBe(30)
    expect(pages.find(({ month }) => month === 5)?.pages).toBe(1)
  })

  test('counts a book read across New Year on both years', () => {
    const acrossNewYear = [finish('2025-12-22', '2026-01-10', { pages: 200 })]

    expect(pagesPerMonthOf(acrossNewYear, 2025)[11].pages).toBe(100)
    expect(pagesPerMonthOf(acrossNewYear, 2026)[0].pages).toBe(100)
  })

  test('ignores a book with no page count', () => {
    const pages = pagesPerMonthOf([finish('2026-03-01', '2026-03-02')], 2026)

    expect(pages.every(({ pages }) => pages === 0)).toBe(true)
  })
})

describe('hours listened per month', () => {
  test('spreads an audiobook evenly over the days it was open', () => {
    // 20 hours over 40 days: 10 in March, 10 in April.
    const hours = hoursPerMonthOf([finish('2026-03-12', '2026-04-20', { minutes: 1200 })], 2026)

    expect(hours.find(({ month }) => month === 3)?.hours).toBe(10)
    expect(hours.find(({ month }) => month === 4)?.hours).toBe(10)
  })

  test('counts an audiobook finished across New Year on both years', () => {
    const acrossNewYear = [finish('2025-12-22', '2026-01-10', { minutes: 1200 })]

    expect(hoursPerMonthOf(acrossNewYear, 2025)[11].hours).toBe(10)
    expect(hoursPerMonthOf(acrossNewYear, 2026)[0].hours).toBe(10)
  })

  test('ignores a book with no running time, which is every printed book', () => {
    const hours = hoursPerMonthOf([finish('2026-03-01', '2026-03-02', { pages: 400 })], 2026)

    expect(hours.every(({ hours }) => hours === 0)).toBe(true)
  })

  test('rounds a month of a few minutes down to nothing', () => {
    const hours = hoursPerMonthOf([finish('2026-03-01', '2026-03-01', { minutes: 20 })], 2026)

    expect(hours[2].hours).toBe(0)
  })
})

describe('the books read trend', () => {
  test('counts this year books against those finished by the same date last year', () => {
    const finishes = [
      finish('2026-01-01', '2026-02-10'),
      finish('2026-03-01', '2026-03-20'),
      finish('2025-01-01', '2025-02-01'),
      finish('2025-11-01', '2025-11-30'),
    ]

    expect(booksReadTrendOf(finishes, day('2026-09-15'))).toEqual({ current: 2, previous: 1 })
  })

  test('compares with zero when last year finished its books later in the year', () => {
    const trend = booksReadTrendOf(
      [finish('2026-01-01', '2026-01-10'), finish('2025-10-01', '2025-10-20')],
      day('2026-09-15'),
    )

    expect(trend).toEqual({ current: 1, previous: 0 })
  })

  test('draws no comparison when last year finished nothing', () => {
    expect(
      booksReadTrendOf([finish('2026-01-01', '2026-01-10')], day('2026-09-15')).previous,
    ).toBeUndefined()
  })

  test('has no figure before the first book of the year', () => {
    expect(
      booksReadTrendOf([finish('2025-01-01', '2025-01-10')], day('2026-09-15')).current,
    ).toBeUndefined()
  })
})

describe('the to-read pile', () => {
  test('lasts the pile size divided by the monthly pace of the last twelve months', () => {
    const finishes = Array.from({ length: 12 }, (_, index) =>
      finish(`2026-0${(index % 9) + 1}-01`, `2026-0${(index % 9) + 1}-02`),
    )

    expect(monthsToClearPileOf(finishes, 27, day('2026-09-15'))).toBe(27)
  })

  test('has no estimate without a pace to divide by', () => {
    expect(
      monthsToClearPileOf([finish('2020-01-01', '2020-01-02')], 5, day('2026-09-15')),
    ).toBeUndefined()
  })
})

describe('the average rating', () => {
  test('averages the rated books to one decimal, ignoring the unrated', () => {
    const finishes = [
      finish('2026-01-01', '2026-01-02', { rating: 5 }),
      finish('2026-01-01', '2026-01-02', { rating: 4 }),
      finish('2026-01-01', '2026-01-02', { rating: 4 }),
      finish('2026-01-01', '2026-01-02'),
    ]

    expect(averageRatingOf(finishes)).toBe(4.3)
  })
})

describe('the genres read', () => {
  test('keeps four genres and gathers the rest, other and unclassified into one segment', () => {
    const read = (genre: Genre | undefined, count: number) =>
      Array.from({ length: count }, () => finish('2026-01-01', '2026-01-02', { genre }))
    const finishes = [
      ...read('fantasy', 5),
      ...read('crime', 4),
      ...read('romance', 3),
      ...read('essay', 2),
      ...read('poetry', 1),
      ...read('other', 1),
      ...read(undefined, 1),
    ]

    expect(genresOf(finishes)).toEqual([
      { genre: 'fantasy', count: 5 },
      { genre: 'crime', count: 4 },
      { genre: 'romance', count: 3 },
      { genre: 'essay', count: 2 },
      { count: 3 },
    ])
  })

  test('count the books of every year, not only this one', () => {
    const finishes = [
      finish('2024-03-01', '2024-03-10', { genre: 'fantasy' }),
      finish('2025-06-01', '2025-06-10', { genre: 'fantasy' }),
      finish('2026-01-01', '2026-01-02', { genre: 'crime' }),
    ]

    expect(genresOf(finishes)).toEqual([
      { genre: 'fantasy', count: 2 },
      { genre: 'crime', count: 1 },
    ])
  })
})

describe('building the view', () => {
  const reader = 'reader-1' as UserId
  const kingkiller = 'kingkiller' as SeriesId
  const catalogue: Series = {
    id: kingkiller,
    name: SeriesName('Chronique du tueur de roi'),
    author: AuthorName('Patrick Rothfuss'),
    volumes: [
      {
        kind: 'main',
        number: VolumeNumber(1),
        title: BookTitle('Le Nom du vent'),
        publishedIn: Year(2007),
      },
      {
        kind: 'main',
        number: VolumeNumber(2),
        title: BookTitle('La Peur du sage'),
        publishedIn: Year(2011),
      },
      {
        kind: 'main',
        number: VolumeNumber(3),
        title: BookTitle('Les Portes de pierre'),
        publishedIn: Year(2030),
      },
      { kind: 'novella', title: BookTitle("L'Éclair de silence"), publishedIn: Year(2014) },
    ],
    catalogedAt: new Date('2026-01-01'),
  }

  const book = (id: string, overrides: Partial<Book>): Book => ({
    id: BookId(id),
    userId: reader,
    title: BookTitle(id),
    authors: [],
    format: 'book',
    media: ['print'],
    subgenres: [],
    narrators: [],
    status: 'to-read',
    hidden: false,
    addedAt: new Date('2026-01-01T10:00:00.000Z'),
    ...overrides,
  })

  test('measures a saga on its published numbered volumes only', () => {
    const books = [
      book('vol-1', {
        status: 'read',
        startedAt: new Date('2026-02-01'),
        finishedAt: new Date('2026-02-10'),
        series: { id: kingkiller, name: catalogue.name, volume: VolumeNumber(1), kind: 'main' },
      }),
    ]

    expect(seriesProgressOf(books, [catalogue], 2026)).toMatchObject([
      { id: kingkiller, readCount: 1, totalCount: 2 },
    ])
  })

  // The Series tab calls it not started: the saga has not begun, so it is not
  // in progress either.
  test('leaves out a saga none of whose volumes has been opened', () => {
    const books = [
      book('vol-1', {
        series: { id: kingkiller, name: catalogue.name, volume: VolumeNumber(1), kind: 'main' },
      }),
      book('vol-2', {
        series: { id: kingkiller, name: catalogue.name, volume: VolumeNumber(2), kind: 'main' },
      }),
    ]

    expect(seriesProgressOf(books, [catalogue], 2026)).toEqual([])
  })

  test('keeps a saga whose first volume is being read', () => {
    const books = [
      book('vol-1', {
        status: 'reading',
        startedAt: new Date('2026-02-01'),
        series: { id: kingkiller, name: catalogue.name, volume: VolumeNumber(1), kind: 'main' },
      }),
    ]

    expect(seriesProgressOf(books, [catalogue], 2026)).toMatchObject([
      { id: kingkiller, readCount: 0, totalCount: 2 },
    ])
  })

  test('leaves out a saga whose published volumes are all read', () => {
    const volume = (number: number) =>
      book(`vol-${number}`, {
        status: 'read',
        startedAt: new Date('2026-02-01'),
        finishedAt: new Date('2026-02-10'),
        series: {
          id: kingkiller,
          name: catalogue.name,
          volume: VolumeNumber(number),
          kind: 'main',
        },
      })

    expect(seriesProgressOf([volume(1), volume(2)], [catalogue], 2026)).toEqual([])
  })

  // The Series tab holds each edition as its own row, dated on its own books:
  // the edition in progress is the one the card shows, on its own date.
  test('measures the edition in progress, dated on its own volumes', () => {
    const volume = (language: 'fr' | 'en', status: 'read' | 'to-read', finishedAt?: string) =>
      book(`${language}-1`, {
        status,
        language,
        startedAt: finishedAt ? new Date(finishedAt) : undefined,
        finishedAt: finishedAt ? new Date(finishedAt) : undefined,
        series: { id: kingkiller, name: catalogue.name, volume: VolumeNumber(1), kind: 'main' },
      })
    const books = [
      volume('en', 'read', '2026-09-01'),
      book('en-2', {
        status: 'read',
        language: 'en',
        startedAt: new Date('2026-09-05'),
        finishedAt: new Date('2026-09-10'),
        series: { id: kingkiller, name: catalogue.name, volume: VolumeNumber(2), kind: 'main' },
      }),
      volume('fr', 'read', '2026-03-01'),
    ]
    // Each edition is measured on its own catalogue.
    const editions = [
      { ...catalogue, language: 'fr' as const },
      { ...catalogue, language: 'en' as const },
    ]

    expect(seriesProgressOf(books, editions, 2026)).toEqual([
      expect.objectContaining({ id: kingkiller, readCount: 1, totalCount: 2 }),
    ])
    expect(seriesProgressOf(books, editions, 2026)[0]?.lastActivityAt).toEqual(
      new Date('2026-03-01'),
    )
    // Without the French catalogue, the French row has nothing to measure.
    expect(seriesProgressOf(books, [{ ...catalogue, language: 'en' as const }], 2026)).toEqual([])
  })

  // The card reads as the top of the Series tab: the saga whose latest volume
  // was shelved most recently first, whatever the reader thinks of it.
  test('puts the sagas in progress in the Series tab order, and shows six', () => {
    const sagaOf = (name: string): Series => ({
      ...catalogue,
      id: name as SeriesId,
      name: SeriesName(name),
    })
    const sagas = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'].map(sagaOf)
    const firstVolume = (saga: Series, finishedAt: string, rating?: number) =>
      book(`${saga.id}-1`, {
        status: 'read',
        startedAt: new Date(finishedAt),
        finishedAt: new Date(finishedAt),
        rating: rating === undefined ? undefined : StarRating(rating),
        series: { id: saga.id, name: saga.name, volume: VolumeNumber(1), kind: 'main' },
      })
    const view = analyticsViewOf({
      userId: reader,
      timeZone: paris,
      now: new Date('2026-09-15T10:00:00.000Z'),
      catalogues: sagas,
      // A hearted saga shelved long ago does not lift itself above the others.
      opinions: [
        { userId: reader, seriesId: 'b' as SeriesId, rating: StarRating(5), favorite: true },
      ],
      books: [
        firstVolume(sagas[0], '2026-09-01'),
        firstVolume(sagas[1], '2026-01-01'),
        firstVolume(sagas[2], '2026-02-01', 5),
        firstVolume(sagas[3], '2026-03-01', 4),
        firstVolume(sagas[4], '2026-04-01', 4),
        firstVolume(sagas[5], '2026-05-01'),
        firstVolume(sagas[6], '2026-06-01'),
        firstVolume(sagas[7], '2026-07-01'),
      ],
    })

    const series = dashboardOf(view, day('2026-09-15')).series

    expect(series.map((entry) => entry.id)).toEqual(['a', 'h', 'g', 'f', 'e', 'd'] as SeriesId[])
    // What the card draws beside each saga: the heart, else the stars.
    expect(series[4]).toMatchObject({ id: 'e', rating: 4, favorite: false })
  })

  test('sorts the shelves and keeps the last finished book', () => {
    const view = analyticsViewOf({
      userId: reader,
      timeZone: paris,
      now: new Date('2026-09-15T10:00:00.000Z'),
      catalogues: [],
      books: [
        book('early', { status: 'reading', startedAt: new Date('2026-08-01') }),
        book('late', { status: 'reading', startedAt: new Date('2026-09-01') }),
        book('first', {
          status: 'read',
          startedAt: new Date('2026-01-01'),
          finishedAt: new Date('2026-01-09'),
        }),
        book('last', {
          status: 'read',
          startedAt: new Date('2026-06-01'),
          finishedAt: new Date('2026-06-09'),
        }),
        book('pile', {}),
      ],
    })

    expect(view.reading.map(({ id }) => String(id))).toEqual(['late', 'early'])
    expect(String(view.lastFinished?.id)).toBe('last')
    expect(view.toRead).toHaveLength(1)
    expect(view.finishes).toHaveLength(2)
    expect(view.stale).toBe(false)
    expect(view.version).toBe(VIEW_VERSION)
  })

  // The dashboard shelf and the Library tab must agree on where a book sits:
  // the first cover on the dashboard is the first row of the library.
  test('shelves the books in progress as the library does', () => {
    const view = analyticsViewOf({
      userId: reader,
      timeZone: paris,
      now: new Date('2026-09-15T10:00:00.000Z'),
      catalogues: [],
      books: [
        book('beta', { status: 'reading', startedAt: new Date('2026-08-01') }),
        book('alpha', { status: 'reading', startedAt: new Date('2026-08-01') }),
        book('reread', {
          status: 'reading',
          startedAt: new Date('2026-07-01'),
          finishedAt: new Date('2026-09-01'),
        }),
      ],
    })

    expect(view.reading.map(({ id }) => String(id))).toEqual(['reread', 'alpha', 'beta'])
  })

  // A saga is hearted once whatever the number of its volumes on the shelf, so
  // its heart is counted beside the books' rather than through them.
  test('counts the hearted books and sagas, and the recordings', () => {
    const view = analyticsViewOf({
      userId: reader,
      timeZone: paris,
      now: new Date('2026-09-15T10:00:00.000Z'),
      catalogues: [],
      opinions: [
        { userId: reader, seriesId: kingkiller, favorite: true },
        { userId: reader, seriesId: 'dune' as SeriesId, rating: StarRating(4) },
      ],
      books: [
        book('loved', { favorite: true }),
        book('heard', { format: 'audiobook' }),
        book('plain', {}),
        book('put-down', { status: 'dropped' }),
      ],
    })

    expect(view.favoriteBookCount).toBe(1)
    expect(view.favoriteSeriesCount).toBe(1)
    expect(view.audiobookCount).toBe(1)
    expect(view.printedBookCount).toBe(3)
    expect(view.droppedCount).toBe(1)

    const today = day('2026-09-15')
    expect(dashboardOf(view, today).favoriteCount).toBe(2)
    expect(dashboardOf(view, today).hasAudiobooks).toBe(true)
    expect(dashboardOf(view, today).hasPrintedBooks).toBe(true)
    expect(dashboardOf(view, today).droppedCount).toBe(1)
  })

  // Every book finished since the reader's first, whatever the year.
  test('counts every book read since the start', () => {
    const view = analyticsViewOf({
      userId: reader,
      timeZone: paris,
      now: new Date('2026-09-15T10:00:00.000Z'),
      catalogues: [],
      books: [
        book('long-ago', { status: 'read', finishedAt: new Date('2012-05-01') }),
        book('this-year', { status: 'read', finishedAt: new Date('2026-05-01') }),
        book('open', { status: 'reading' }),
      ],
    })

    expect(dashboardOf(view, day('2026-09-15')).readCount).toBe(2)
  })

  // A library of recordings only has no page to chart.
  test('reads a library of audiobooks only as holding no printed book', () => {
    const view = analyticsViewOf({
      userId: reader,
      timeZone: paris,
      now: new Date('2026-09-15T10:00:00.000Z'),
      catalogues: [],
      books: [book('heard', { format: 'audiobook' })],
    })

    expect(dashboardOf(view, day('2026-09-15')).hasPrintedBooks).toBe(false)
  })

  // A view stored before these figures existed answers nothing for them, and
  // nothing must read as zero, not as a crash.
  test('reads a view built before the counters as empty', () => {
    const legacy = analyticsViewOf({
      userId: reader,
      timeZone: paris,
      now: new Date('2026-09-15T10:00:00.000Z'),
      catalogues: [],
      books: [],
    })
    const {
      favoriteBookCount,
      favoriteSeriesCount,
      audiobookCount,
      printedBookCount,
      droppedCount,
      ...stored
    } = legacy

    const dashboard = dashboardOf(stored, day('2026-09-15'))
    expect(dashboard.favoriteCount).toBe(0)
    expect(dashboard.hasAudiobooks).toBe(false)
    expect(dashboard.hasPrintedBooks).toBe(true)
    expect(dashboard.droppedCount).toBe(0)
  })

  // A saga rated as a whole rates each of its volumes the reader left unrated:
  // the stars drawn on the book are the ones the statistics count.
  test('rates a finished volume left unrated with the rating of its saga', () => {
    const inSaga = { id: kingkiller, name: catalogue.name, kind: 'main' as const }
    const view = analyticsViewOf({
      userId: reader,
      timeZone: paris,
      now: new Date('2026-09-15T10:00:00.000Z'),
      catalogues: [],
      opinions: [{ userId: reader, seriesId: kingkiller, rating: StarRating(4) }],
      books: [
        book('inherits', {
          status: 'read',
          finishedAt: new Date('2026-06-01'),
          series: { ...inSaga, volume: VolumeNumber(1) },
        }),
        book('own', {
          status: 'read',
          finishedAt: new Date('2026-06-02'),
          rating: StarRating(2),
          series: { ...inSaga, volume: VolumeNumber(2) },
        }),
        book('standalone', { status: 'read', finishedAt: new Date('2026-06-03') }),
      ],
    })

    expect(view.finishes.map((finish) => [String(finish.bookId), finish.rating])).toEqual([
      ['inherits', StarRating(4)],
      ['own', StarRating(2)],
      ['standalone', undefined],
    ])
    expect(view.lastFinished?.rating).toBeUndefined()

    const dashboard = dashboardOf(view, day('2026-09-15'))
    expect(dashboard.ratedCount).toBe(2)
    expect(dashboard.averageRating).toBe(3)
  })

  // "Series in progress" lists what the reader is working through; a saga they
  // stopped following is set aside, however far they got.
  test('leaves a saga the reader stopped following off the progress bars', () => {
    const view = analyticsViewOf({
      userId: reader,
      timeZone: paris,
      now: new Date('2026-09-15T10:00:00.000Z'),
      catalogues: [catalogue],
      opinions: [{ userId: reader, seriesId: kingkiller, unfollowed: true }],
      books: [
        book('vol-1', {
          status: 'read',
          finishedAt: new Date('2026-02-10'),
          series: { id: kingkiller, name: catalogue.name, volume: VolumeNumber(1), kind: 'main' },
        }),
      ],
    })

    expect(view.series).toEqual([])
  })

  test('draws the saga rating on an unrated volume in progress', () => {
    const view = analyticsViewOf({
      userId: reader,
      timeZone: paris,
      now: new Date('2026-09-15T10:00:00.000Z'),
      catalogues: [],
      opinions: [{ userId: reader, seriesId: kingkiller, rating: StarRating(5) }],
      books: [
        book('open', {
          status: 'reading',
          startedAt: new Date('2026-09-01'),
          series: { id: kingkiller, name: catalogue.name, volume: VolumeNumber(1), kind: 'main' },
        }),
      ],
    })

    expect(view.reading[0]?.rating).toBe(StarRating(5))
  })

  test('tells a recording from a book on every card, so its cover carries the headphones', () => {
    const view = analyticsViewOf({
      userId: reader,
      timeZone: paris,
      now: new Date('2026-09-15T10:00:00.000Z'),
      catalogues: [],
      opinions: [],
      books: [
        book('heard', { status: 'reading', format: 'audiobook' }),
        book('done', { status: 'read', format: 'audiobook', finishedAt: new Date('2026-09-10') }),
      ],
    })

    expect(view.reading[0]?.format).toBe('audiobook')
    expect(view.lastFinished?.format).toBe('audiobook')
  })
})

describe('the reading challenge', () => {
  const book = (id: string, overrides: Partial<Book>): Book => ({
    id: BookId(id),
    userId: 'reader-1' as UserId,
    title: BookTitle(id),
    authors: [],
    format: 'book',
    media: ['print'],
    subgenres: [],
    narrators: [],
    status: 'read',
    hidden: false,
    addedAt: new Date('2025-01-01T10:00:00.000Z'),
    ...overrides,
  })

  test('counts the books finished each year, in the reader time zone', () => {
    const books = [
      book('a', { finishedAt: new Date('2025-06-01T10:00:00.000Z') }),
      // Late on December 31st in UTC is already the new year in Paris.
      book('b', { finishedAt: new Date('2025-12-31T23:30:00.000Z') }),
      book('c', { finishedAt: new Date('2026-03-01T10:00:00.000Z') }),
      book('reading', { status: 'reading' }),
      book('undated', {}),
    ]

    expect(readPerYearOf(books, paris)).toEqual([
      { year: 2025, count: 1 },
      { year: 2026, count: 2 },
    ])
  })

  test('leaves the books kept to oneself out', () => {
    const shelf = sharedShelfOf(
      [
        book('shared', { finishedAt: new Date('2026-03-01T10:00:00.000Z') }),
        book('secret', { finishedAt: new Date('2026-04-01T10:00:00.000Z'), hidden: true }),
      ],
      paris,
    )

    expect(shelf.readPerYear).toEqual([{ year: 2026, count: 1 }])
  })

  test('reads this year off the shelf, and nothing on a year with no book', () => {
    const shelf = sharedShelfOf(
      [book('a', { finishedAt: new Date('2025-03-01T10:00:00.000Z') })],
      paris,
    )

    expect(sharedShelfTodayOf(shelf, day('2025-09-27')).readThisYear).toBe(1)
    expect(sharedShelfTodayOf(shelf, day('2026-01-01')).readThisYear).toBe(0)
  })
})

describe('the genre insights', () => {
  let counter = 0
  const book = (overrides: Partial<Book>): Book => ({
    id: BookId(`book-${++counter}`),
    userId: 'reader-1' as UserId,
    title: BookTitle(`Book ${counter}`),
    authors: [],
    format: 'book',
    media: ['print'],
    subgenres: [],
    narrators: [],
    status: 'read',
    hidden: false,
    addedAt: new Date('2025-01-01T10:00:00.000Z'),
    ...overrides,
  })
  const many = (count: number, overrides: Partial<Book>) =>
    Array.from({ length: count }, () => book(overrides))
  const rated = (genre: Genre, ratings: number[]) =>
    ratings.map((rating) => book({ genre, rating: StarRating(rating) }))

  test('ranks the genres read, leaving out "other" and books without a genre', () => {
    const insights = genreInsightsOf([
      ...many(3, { genre: 'fantasy' }),
      ...many(2, { genre: 'crime' }),
      ...many(2, { genre: 'other' }),
      book({}),
      book({ genre: 'horror', status: 'to-read' }),
    ])

    expect(insights.readCount).toBe(8)
    expect(insights.shares).toEqual([
      { genre: 'fantasy', count: 3 },
      { genre: 'crime', count: 2 },
    ])
  })

  test('gives each format the genre it carries most', () => {
    const insights = genreInsightsOf([
      ...many(2, { format: 'audiobook', genre: 'fantasy' }),
      book({ format: 'audiobook', genre: 'crime' }),
      book({ format: 'manga' }),
      ...many(4, { format: 'book', genre: 'crime' }),
    ])

    expect(insights.formats).toEqual([
      { format: 'book', count: 4, topGenre: 'crime' },
      { format: 'audiobook', count: 3, topGenre: 'fantasy' },
      { format: 'manga', count: 1, topGenre: undefined },
    ])
  })

  test('places on the taste map only the genres with three rated books', () => {
    const insights = genreInsightsOf([
      ...rated('fantasy', [4, 4, 5]),
      book({ genre: 'fantasy' }),
      ...rated('crime', [5, 5]),
    ])

    expect(insights.tastes).toEqual([{ genre: 'fantasy', readCount: 4, averageRating: 4.3 }])
    expect(insights.averageRating).toBe(4.6)
  })

  test('points out a genre read little and liked well above the average', () => {
    const insights = genreInsightsOf([
      ...rated('fantasy', [4, 4, 4, 4, 4, 4, 4, 4]),
      ...rated('crime', [3, 4, 3, 4, 3, 4]),
      ...rated('historical-fiction', [5, 5, 5]),
    ])

    expect(insights.hiddenGem).toBe('historical-fiction')
  })

  test('points out no gem rated too close to the average, or among too few genres', () => {
    const taste = (genre: Genre, readCount: number, averageRating: number) => ({
      genre,
      readCount,
      averageRating,
    })
    const tastes = [taste('fantasy', 8, 4), taste('crime', 6, 3.5), taste('romance', 3, 4.3)]

    expect(hiddenGemOf(tastes, 4)).toBeUndefined()
    expect(hiddenGemOf(tastes.slice(1), 3)).toBeUndefined()
    expect(hiddenGemOf(tastes, undefined)).toBeUndefined()
  })

  test('breaks a tie between gems on the fewer books read', () => {
    const taste = (genre: Genre, readCount: number, averageRating: number) => ({
      genre,
      readCount,
      averageRating,
    })

    expect(
      hiddenGemOf(
        [
          taste('fantasy', 9, 3.5),
          taste('crime', 8, 3.5),
          taste('romance', 4, 5),
          taste('poetry', 3, 5),
        ],
        4,
      )?.genre,
    ).toBe('poetry')
  })

  test('crowns the longest genre on its average pages, from three books on', () => {
    const insights = genreInsightsOf([
      ...[600, 700, 650].map((pages) => book({ genre: 'fantasy', pageCount: PageCount(pages) })),
      ...[900, 900].map((pages) => book({ genre: 'history', pageCount: PageCount(pages) })),
      ...[300, 320, 280].map((pages) => book({ genre: 'crime', pageCount: PageCount(pages) })),
    ])

    expect(insights.longest).toEqual({ genre: 'fantasy', averagePages: 650 })
  })

  test('crowns the fastest genre, a book read within the day counting one day', () => {
    const read = (genre: Genre, days: number) =>
      book({
        genre,
        startedAt: new Date('2026-03-01T08:00:00.000Z'),
        finishedAt: new Date(Date.parse('2026-03-01T08:00:00.000Z') + days * 86_400_000),
      })
    const insights = genreInsightsOf([
      read('thriller', 0),
      read('thriller', 2),
      read('thriller', 3),
      read('fantasy', 20),
      read('fantasy', 30),
      read('fantasy', 25),
      book({ genre: 'crime', startedAt: new Date('2026-03-01') }),
    ])

    expect(insights.fastest).toEqual({ genre: 'thriller', averageDays: 2 })
  })

  test('holds no record without three books behind it', () => {
    const insights = genreInsightsOf([
      book({ genre: 'fantasy', pageCount: PageCount(800) }),
      book({ genre: 'essay', status: 'dropped' }),
    ])

    expect(insights.longest).toBeUndefined()
    expect(insights.fastest).toBeUndefined()
    expect(insights.mostDropped).toBeUndefined()
    expect(insights.tastes).toEqual([])
    expect(insights.hiddenGem).toBeUndefined()
  })

  test('finds the genre given up most often, out of the books of it opened', () => {
    const insights = genreInsightsOf([
      ...many(3, { genre: 'essay', status: 'dropped' }),
      ...many(3, { genre: 'essay' }),
      book({ genre: 'essay', status: 'reading' }),
      ...many(5, { genre: 'essay', status: 'to-read' }),
      ...many(2, { genre: 'crime', status: 'dropped' }),
      ...many(2, { genre: 'crime' }),
      ...many(4, { genre: 'fantasy' }),
    ])

    expect(insights.mostDropped).toEqual({ genre: 'crime', droppedCount: 2, startedCount: 4 })
  })

  test('breaks an equal drop rate on the more books dropped', () => {
    const insights = genreInsightsOf([
      ...many(2, { genre: 'crime', status: 'dropped' }),
      ...many(2, { genre: 'crime' }),
      ...many(3, { genre: 'essay', status: 'dropped' }),
      ...many(3, { genre: 'essay' }),
    ])

    expect(insights.mostDropped).toEqual({ genre: 'essay', droppedCount: 3, startedCount: 6 })
  })

  test('lists the genres never finished, those waiting on the pile first', () => {
    const insights = genreInsightsOf([
      book({ genre: 'fantasy' }),
      book({ genre: 'travel', status: 'to-read' }),
      book({ genre: 'poetry', status: 'dropped' }),
    ])
    const genres = insights.unexplored.map(({ genre }) => genre)

    expect(insights.unexplored[0]).toEqual({ genre: 'travel', pileCount: 1 })
    expect(genres).toContain('poetry')
    expect(genres).not.toContain('fantasy')
    expect(genres).not.toContain('other')
    expect(genres).toHaveLength(20)
  })

  const tagged = (label: string) => ({ label: Subgenre(label), language: 'fr' as const })
  const ratedIn = (genre: Genre, subgenre: string | undefined, ratings: number[]) =>
    ratings.map((rating) =>
      book({
        genre,
        rating: StarRating(rating),
        subgenres: subgenre === undefined ? [] : [tagged(subgenre), tagged('Autre chose')],
      }),
    )

  test('places a subgenre apart once it gathers three rated books, the rest in their genre', () => {
    const insights = genreInsightsOf([
      ...ratedIn('fantasy', 'Dark fantasy', [5, 5, 4]),
      ...ratedIn('fantasy', 'Fantasy urbaine', [3, 3]),
      ...ratedIn('fantasy', undefined, [4]),
    ])

    expect(insights.tasteMap).toEqual([
      { genre: 'fantasy', subgenre: undefined, readCount: 3, averageRating: 3.3 },
      { genre: 'fantasy', subgenre: Subgenre('Dark fantasy'), readCount: 3, averageRating: 4.7 },
    ])
    expect(insights.tastes).toEqual([
      { genre: 'fantasy', subgenre: undefined, readCount: 6, averageRating: 4 },
    ])
  })

  test('meets two spellings of one subgenre, case and hyphens aside', () => {
    const insights = genreInsightsOf([
      ...ratedIn('science-fiction', 'Space opera', [4, 4]),
      ...ratedIn('science-fiction', 'Space-Opera', [5]),
    ])

    expect(insights.tasteMap.map(({ subgenre, readCount }) => ({ subgenre, readCount }))).toEqual([
      { subgenre: Subgenre('Space opera'), readCount: 3 },
    ])
    expect(subgenreKeyOf('Space‑Opera ')).toBe('space opera')
  })

  test('keeps one subgenre of two genres apart', () => {
    const insights = genreInsightsOf([
      ...ratedIn('science-fiction', 'Uchronie', [4, 4]),
      ...ratedIn('historical-fiction', 'Uchronie', [4]),
    ])

    expect(insights.tasteMap.map(({ genre, subgenre }) => ({ genre, subgenre }))).toEqual([])
  })

  test('points out a subgenre as the gem, while the old field names its genre', () => {
    const insights = genreInsightsOf([
      ...ratedIn('fantasy', undefined, [4, 4, 4, 4, 4, 4, 4, 4]),
      ...ratedIn('crime', undefined, [3, 4, 3, 4, 3, 4]),
      ...ratedIn('historical-fiction', 'Uchronie', [5, 5, 5]),
    ])

    expect(insights.gem).toEqual({
      genre: 'historical-fiction',
      subgenre: Subgenre('Uchronie'),
      readCount: 3,
      averageRating: 5,
    })
    expect(insights.hiddenGem).toBe('historical-fiction')
  })

  test('takes the median of an odd and of an even count of values', () => {
    expect(medianOf([5, 1, 3])).toBe(3)
    expect(medianOf([8, 2, 4, 6])).toBe(5)
  })
})
