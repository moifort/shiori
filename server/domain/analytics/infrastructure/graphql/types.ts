import type {
  Dashboard,
  DashboardBook,
  FormatShare,
  GenreCount,
  GenreInsights,
  GenreShare,
  GenreTaste,
  MonthHours,
  MonthPages,
  SeriesProgress,
  Trend,
  UnexploredGenre,
  YearCount,
} from '~/domain/analytics/types'
import { BookFormatEnum, GenreEnum } from '~/domain/book/infrastructure/graphql/enums'
import { isAudioSeries } from '~/domain/series/primitives'
import { builder } from '~/domain/shared/graphql/builder'
import { Percentage } from '~/domain/shared/primitives'

const DashboardBookType = builder.objectRef<DashboardBook>('DashboardBook').implement({
  description: 'A book as a dashboard tile draws it: a cover and two lines, nothing more.',
  fields: (t) => ({
    id: t.field({ type: 'BookId', resolve: (book) => book.id }),
    title: t.field({ type: 'BookTitle', resolve: (book) => book.title }),
    authors: t.field({ type: ['AuthorName'], resolve: (book) => book.authors }),
    format: t.field({ type: BookFormatEnum, resolve: (book) => book.format }),
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
    audio: t.boolean({
      description: 'The saga heard rather than read, measured on its recordings.',
      resolve: (series) => isAudioSeries(series.id),
    }),
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
    lastFinished: t.field({
      type: DashboardBookType,
      nullable: true,
      resolve: (dashboard) => dashboard.lastFinished ?? null,
    }),
    booksRead: t.field({
      type: TrendType,
      description: 'Books finished this year to date. Null `current` before the first one.',
      resolve: (dashboard) => dashboard.booksRead,
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
      description:
        'Every book finished, whatever the year: four genres, then one "others" segment.',
      resolve: (dashboard) => dashboard.genres,
    }),
    series: t.field({
      type: [SeriesProgressType],
      description:
        "Sagas in progress, six at most, in the Series tab's order: the saga whose " +
        'latest volume was shelved most recently first.',
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

const GenreShareType = builder.objectRef<GenreShare>('GenreShare').implement({
  description: 'How many finished books carry one genre.',
  fields: (t) => ({
    genre: t.field({ type: GenreEnum, resolve: (share) => share.genre }),
    count: t.exposeInt('count'),
  }),
})

const FormatShareType = builder.objectRef<FormatShare>('FormatShare').implement({
  description: 'How many finished books came in one format, and the genre it carries most.',
  fields: (t) => ({
    format: t.field({ type: BookFormatEnum, resolve: (share) => share.format }),
    count: t.exposeInt('count'),
    topGenre: t.field({
      type: GenreEnum,
      nullable: true,
      description: 'Null when no book of the format has a genre other than OTHER.',
      resolve: (share) => share.topGenre ?? null,
    }),
  }),
})

const GenreTasteType = builder.objectRef<GenreTaste>('GenreTaste').implement({
  description:
    'One place on the taste map: how many of its books the reader finished against ' +
    'how they rated them. Only places with three rated books are drawn.',
  fields: (t) => ({
    genre: t.field({ type: GenreEnum, resolve: (taste) => taste.genre }),
    subgenre: t.field({
      type: 'Subgenre',
      nullable: true,
      description:
        'The head subgenre of the books placed here, as the reader first wrote it. ' +
        'Null for the books of the genre that no subgenre took.',
      resolve: (taste) => taste.subgenre ?? null,
    }),
    readCount: t.exposeInt('readCount', { description: 'Finished books, rated or not.' }),
    averageRating: t.exposeFloat('averageRating', {
      description: 'The average of the rated ones, to one decimal.',
    }),
  }),
})

const LongestGenreType = builder
  .objectRef<NonNullable<GenreInsights['longest']>>('LongestGenre')
  .implement({
    description: 'The genre whose finished books run longest.',
    fields: (t) => ({
      genre: t.field({ type: GenreEnum, resolve: (record) => record.genre }),
      averagePages: t.exposeInt('averagePages'),
    }),
  })

const FastestGenreType = builder
  .objectRef<NonNullable<GenreInsights['fastest']>>('FastestGenre')
  .implement({
    description:
      'The genre read fastest, in days from the first page to the last, a book read ' +
      'within the day counting one.',
    fields: (t) => ({
      genre: t.field({ type: GenreEnum, resolve: (record) => record.genre }),
      averageDays: t.exposeInt('averageDays'),
    }),
  })

const MostDroppedGenreType = builder
  .objectRef<NonNullable<GenreInsights['mostDropped']>>('MostDroppedGenre')
  .implement({
    description: 'The genre given up most often, out of the books of it ever opened.',
    fields: (t) => ({
      genre: t.field({ type: GenreEnum, resolve: (record) => record.genre }),
      droppedCount: t.exposeInt('droppedCount'),
      startedCount: t.exposeInt('startedCount', {
        description: 'Books of the genre read, being read or dropped.',
      }),
    }),
  })

const UnexploredGenreType = builder.objectRef<UnexploredGenre>('UnexploredGenre').implement({
  description: 'A genre the reader never finished a book of.',
  fields: (t) => ({
    genre: t.field({ type: GenreEnum, resolve: (entry) => entry.genre }),
    pileCount: t.exposeInt('pileCount', {
      description: 'Books of the genre waiting on the pile.',
    }),
  }),
})

export const GenreInsightsType = builder.objectRef<GenreInsights>('GenreInsights').implement({
  description:
    "What the reader's books say about their tastes, genre by genre. A record or a " +
    'gem with too few books behind it is null rather than drawn from luck.',
  fields: (t) => ({
    readCount: t.exposeInt('readCount', {
      description: 'Every book finished, with or without a genre.',
    }),
    shares: t.field({
      type: [GenreShareType],
      description: 'The genres read, the most read first, OTHER and books without one aside.',
      resolve: (insights) => insights.shares,
    }),
    formats: t.field({
      type: [FormatShareType],
      description: 'The formats read, the most read first.',
      resolve: (insights) => insights.formats,
    }),
    tastes: t.field({
      type: [GenreTasteType],
      description: 'The genres with three rated books, the most read first.',
      deprecationReason: 'Use tasteMap, which places the subgenres that weigh apart.',
      resolve: (insights) => insights.tastes,
    }),
    tasteMap: t.field({
      type: [GenreTasteType],
      description:
        'The taste map, the most read first: a head subgenre with three rated books ' +
        'of its own placed apart, every other book in its genre.',
      resolve: (insights) => insights.tasteMap,
    }),
    averageRating: t.float({
      nullable: true,
      description: 'The average of every rated finished book: what splits the taste map.',
      resolve: (insights) => insights.averageRating ?? null,
    }),
    hiddenGem: t.field({
      type: GenreEnum,
      nullable: true,
      deprecationReason: 'Use gem, which may name a subgenre.',
      description:
        "A genre read less than the median and rated half a star above the reader's " +
        'average, the best rated if several.',
      resolve: (insights) => insights.hiddenGem ?? null,
    }),
    gem: t.field({
      type: GenreTasteType,
      nullable: true,
      description:
        'The place of tasteMap read less than the median and rated half a star above ' +
        "the reader's average, the best rated if several: a genre or a subgenre.",
      resolve: (insights) => insights.gem ?? null,
    }),
    longest: t.field({
      type: LongestGenreType,
      nullable: true,
      resolve: (insights) => insights.longest ?? null,
    }),
    fastest: t.field({
      type: FastestGenreType,
      nullable: true,
      resolve: (insights) => insights.fastest ?? null,
    }),
    mostDropped: t.field({
      type: MostDroppedGenreType,
      nullable: true,
      resolve: (insights) => insights.mostDropped ?? null,
    }),
    unexplored: t.field({
      type: [UnexploredGenreType],
      description: 'The genres never finished, OTHER aside, those waiting on the pile first.',
      resolve: (insights) => insights.unexplored,
    }),
  }),
})
