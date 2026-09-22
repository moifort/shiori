import { describe, expect, test } from 'bun:test'
import {
  analyticsViewOf,
  averageRatingOf,
  booksPerYearOf,
  dashboardOf,
  daysToFinishTrendOf,
  genresOf,
  hoursPerMonthOf,
  localDateOf,
  medianOf,
  monthsToClearPileOf,
  pagesPerDayTrendOf,
  pagesPerMonthOf,
  seriesProgressOf,
  shuffled,
  VIEW_VERSION,
} from '~/domain/analytics/business-rules'
import { LocalDate, TimeZone } from '~/domain/analytics/primitives'
import type { Finish } from '~/domain/analytics/types'
import { BookId, ListeningMinutes, PageCount, StarRating } from '~/domain/book/primitives'
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

describe('the pages per day trend', () => {
  test('divides this year pages by the days elapsed, against the same span last year', () => {
    const finishes = [
      finish('2026-01-01', '2026-01-10', { pages: 100 }),
      finish('2025-01-01', '2025-01-05', { pages: 50 }),
    ]

    expect(pagesPerDayTrendOf(finishes, day('2026-01-10'))).toEqual({ current: 10, previous: 5 })
  })

  test('draws no comparison when last year has no pages', () => {
    const trend = pagesPerDayTrendOf(
      [finish('2026-01-01', '2026-01-10', { pages: 100 })],
      day('2026-01-10'),
    )

    expect(trend.previous).toBeUndefined()
  })

  test('has nothing to say without a single page count', () => {
    expect(pagesPerDayTrendOf([finish('2026-01-01', '2026-01-10')], day('2026-01-10'))).toEqual({})
  })
})

describe('the days to finish trend', () => {
  test('is a median, so one book left open for months does not skew it', () => {
    const finishes = [
      finish('2026-02-01', '2026-02-05'),
      finish('2026-03-01', '2026-03-05'),
      finish('2026-01-01', '2026-07-01'),
    ]

    expect(daysToFinishTrendOf(finishes, day('2026-09-15')).current).toBe(5)
  })

  test('counts a book started and finished the same day as one day', () => {
    expect(
      daysToFinishTrendOf([finish('2026-02-01', '2026-02-01')], day('2026-09-15')).current,
    ).toBe(1)
  })

  test('compares with books finished by the same date last year only', () => {
    const finishes = [finish('2025-03-01', '2025-03-03'), finish('2025-11-01', '2025-11-30')]

    expect(daysToFinishTrendOf(finishes, day('2026-09-15')).previous).toBe(3)
  })

  test('averages the two middle values of an even count', () => {
    expect(medianOf([2, 4, 6, 9])).toBe(5)
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

describe('the genres read this year', () => {
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
      finish('2025-01-01', '2025-01-02', { genre: 'horror' }),
    ]

    expect(genresOf(finishes, 2026)).toEqual([
      { genre: 'fantasy', count: 5 },
      { genre: 'crime', count: 4 },
      { genre: 'romance', count: 3 },
      { genre: 'essay', count: 2 },
      { count: 3 },
    ])
  })
})

describe('the daily suggestions', () => {
  const pile = Array.from({ length: 20 }, (_, index) => index)

  test('come in the same order all day', () => {
    expect(shuffled(pile, 'reader-1:2026-09-15')).toEqual(shuffled(pile, 'reader-1:2026-09-15'))
  })

  test('are drawn again the next day', () => {
    expect(shuffled(pile, 'reader-1:2026-09-16')).not.toEqual(shuffled(pile, 'reader-1:2026-09-15'))
  })

  test('only reorder the pile', () => {
    expect([...shuffled(pile, 'seed')].sort((left, right) => left - right)).toEqual(pile)
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
})
