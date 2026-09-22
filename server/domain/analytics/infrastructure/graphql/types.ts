import type {
  Dashboard,
  DashboardBook,
  GenreCount,
  MonthHours,
  MonthPages,
  SeriesProgress,
  Trend,
  YearCount,
} from '~/domain/analytics/types'
import { GenreEnum } from '~/domain/book/infrastructure/graphql/enums'
import { builder } from '~/domain/shared/graphql/builder'
import { Percentage } from '~/domain/shared/primitives'

const DashboardBookType = builder.objectRef<DashboardBook>('DashboardBook').implement({
  description: 'A book as a dashboard tile draws it: a cover and two lines, nothing more.',
  fields: (t) => ({
    id: t.field({ type: 'BookId', resolve: (book) => book.id }),
    title: t.field({ type: 'BookTitle', resolve: (book) => book.title }),
    authors: t.field({ type: ['AuthorName'], resolve: (book) => book.authors }),
    coverUrl: t.field({
      type: 'CoverUrl',
      nullable: true,
      description: 'Null without a photo or a published cover; draw the placeholder.',
      resolve: (book) => book.coverUrl ?? null,
    }),
    rating: t.field({
      type: 'StarRating',
      nullable: true,
      resolve: (book) => book.rating ?? null,
    }),
    listeningProgress: t.field({
      type: 'Percentage',
      nullable: true,
      description:
        'How far into the recording the Audible player last stopped, in whole ' +
        'percent. Null on anything but an audiobook the player opened.',
      resolve: (book) =>
        book.listeningProgress === undefined ? null : Percentage(book.listeningProgress),
    }),
    startedAt: t.field({
      type: 'DateTime',
      nullable: true,
      resolve: (book) => book.startedAt ?? null,
    }),
    finishedAt: t.field({
      type: 'DateTime',
      nullable: true,
      resolve: (book) => book.finishedAt ?? null,
    }),
  }),
})

const YearCountType = builder.objectRef<YearCount>('YearCount').implement({
  description: 'Books finished in one calendar year.',
  fields: (t) => ({
    year: t.exposeInt('year'),
    count: t.exposeInt('count'),
  }),
})

const MonthPagesType = builder.objectRef<MonthPages>('MonthPages').implement({
  description:
    'Pages read in one month of the current year. Each finished book spreads its ' +
    'page count evenly over the days it was open: progress itself is never tracked.',
  fields: (t) => ({
    month: t.exposeInt('month', { description: '1 for January, 12 for December.' }),
    pages: t.exposeInt('pages'),
  }),
})

const MonthHoursType = builder.objectRef<MonthHours>('MonthHours').implement({
  description:
    'Hours listened in one month of the current year, rounded to the hour. Each ' +
    'finished audiobook spreads its running time evenly over the days it was open, ' +
    'the way pages are spread; a book with no running time counts for nothing, ' +
    'which leaves printed books out on their own.',
  fields: (t) => ({
    month: t.exposeInt('month', { description: '1 for January, 12 for December.' }),
    hours: t.exposeInt('hours'),
  }),
})

const TrendType = builder.objectRef<Trend>('Trend').implement({
  description: 'A figure for this year to date, beside the same span of last year.',
  fields: (t) => ({
    current: t.int({
      nullable: true,
      description: 'Null when this year has nothing to measure yet.',
      resolve: (trend) => trend.current ?? null,
    }),
    previous: t.int({
      nullable: true,
      description: 'Null when last year has nothing to compare against: draw no arrow.',
      resolve: (trend) => trend.previous ?? null,
    }),
  }),
})

const GenreCountType = builder.objectRef<GenreCount>('GenreCount').implement({
  description: 'One segment of the genre bar.',
  fields: (t) => ({
    genre: t.field({
      type: GenreEnum,
      nullable: true,
      description: 'Null on the trailing "others" segment.',
      resolve: (entry) => entry.genre ?? null,
    }),
    count: t.exposeInt('count'),
  }),
})

const SeriesProgressType = builder.objectRef<SeriesProgress>('SeriesProgress').implement({
  description:
    'How far the reader is through a saga in progress, on the numbered volumes ' +
    'already published.',
  fields: (t) => ({
    id: t.field({ type: 'SeriesId', resolve: (series) => series.id }),
    name: t.field({ type: 'SeriesName', resolve: (series) => series.name }),
    readCount: t.exposeInt('readCount'),
    totalCount: t.exposeInt('totalCount'),
    rating: t.float({
      nullable: true,
      description:
        "The reader's rating of the saga, else the average of the volumes they " +
        'rated. Null when they rated neither.',
      resolve: (series) => series.rating ?? null,
    }),
    favorite: t.boolean({
      description: 'The reader hearted the saga, which is five stars.',
      resolve: (series) => series.favorite,
    }),
  }),
})

export const DashboardType = builder.objectRef<Dashboard>('Dashboard').implement({
  description:
    'The home dashboard: reading statistics and the shelves worth a glance.\n\n' +
    'Read from a view rebuilt on every book write, then set against today, so it ' +
    'costs one document read. A section with nothing to show comes back empty or ' +
    'null, and the app leaves it out rather than drawing zeros.',
  fields: (t) => ({
    currentYear: t.exposeInt('currentYear'),
    booksPerYear: t.field({
      type: [YearCountType],
      description: 'From the first finished book to this year, nine years at most.',
      resolve: (dashboard) => dashboard.booksPerYear,
    }),
    pagesPerMonth: t.field({
      type: [MonthPagesType],
      description: 'The twelve months of the current year.',
      resolve: (dashboard) => dashboard.pagesPerMonth,
    }),
    hoursPerMonth: t.field({
      type: [MonthHoursType],
      description: 'The twelve months of the current year.',
      resolve: (dashboard) => dashboard.hoursPerMonth,
    }),
    reading: t.field({
      type: [DashboardBookType],
      description: 'Most recently started first, ten at most.',
      resolve: (dashboard) => dashboard.reading,
    }),
    suggestions: t.field({
      type: [DashboardBookType],
      description: 'Six books of the pile, drawn at random once a day.',
      resolve: (dashboard) => dashboard.suggestions,
    }),
    lastFinished: t.field({
      type: DashboardBookType,
      nullable: true,
      resolve: (dashboard) => dashboard.lastFinished ?? null,
    }),
    pagesPerDay: t.field({ type: TrendType, resolve: (dashboard) => dashboard.pagesPerDay }),
    daysToFinish: t.field({
      type: TrendType,
      description: 'Median days from start to finish, both days included.',
      resolve: (dashboard) => dashboard.daysToFinish,
    }),
    toReadCount: t.exposeInt('toReadCount'),
    readCount: t.exposeInt('readCount', {
      description: 'Every book finished since the first, whatever the year.',
    }),
    monthsToClearPile: t.int({
      nullable: true,
      description: 'At the pace of the last twelve months. Null with no pile or no pace.',
      resolve: (dashboard) => dashboard.monthsToClearPile ?? null,
    }),
    averageRating: t.float({
      nullable: true,
      description: 'One decimal. Null when no finished book is rated.',
      resolve: (dashboard) => dashboard.averageRating ?? null,
    }),
    ratedCount: t.exposeInt('ratedCount'),
    genres: t.field({
      type: [GenreCountType],
      description: 'Books finished this year: four genres, then one "others" segment.',
      resolve: (dashboard) => dashboard.genres,
    }),
    series: t.field({
      type: [SeriesProgressType],
      description:
        'Sagas in progress, six at most: the best rated first, an unrated saga after ' +
        'every rated one, the most recent activity among equals.',
      resolve: (dashboard) => dashboard.series,
    }),
    favoriteCount: t.exposeInt('favoriteCount', {
      description: 'Books and sagas the reader hearted, together.',
    }),
    hasAudiobooks: t.exposeBoolean('hasAudiobooks', {
      description:
        'Whether the library holds a single recording. False, and the listening ' +
        'hours have nothing to chart.',
    }),
    droppedCount: t.exposeInt('droppedCount', {
      description: 'Books the reader dropped because they did not like them.',
    }),
    hasPrintedBooks: t.exposeBoolean('hasPrintedBooks', {
      description:
        'Whether the library holds a single book with pages, printed or electronic. ' +
        'False, and the pages have nothing to chart.',
    }),
    libraryIsEmpty: t.exposeBoolean('libraryIsEmpty', {
      description: 'True when the reader has not catalogued a single book yet.',
    }),
  }),
})
