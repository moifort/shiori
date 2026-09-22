import { readVolumeNumbersOf, shelfDateOf } from '~/domain/book/business-rules'
import { BookLanguageEnum, GenreEnum } from '~/domain/book/infrastructure/graphql/enums'
import { BookType } from '~/domain/book/infrastructure/graphql/types'
import { BookQuery } from '~/domain/book/query'
import type { Book, BookLanguage, Genre } from '~/domain/book/types'
import {
  compareWithinSeries,
  followedSagasOf,
  followedStateOf,
  genreOf,
  inTabOrder,
  matchingFilter,
  progressOf,
} from '~/domain/series/business-rules'
import { SeriesStateEnum } from '~/domain/series/infrastructure/graphql/enums'
import { SeriesType } from '~/domain/series/infrastructure/graphql/types'
import { SeriesQuery } from '~/domain/series/query'
import type { Series, SeriesId, SeriesName, SeriesState } from '~/domain/series/types'
import { SeriesUseCase } from '~/domain/series/use-case'
import { SeriesOpinionType } from '~/domain/series-opinion/infrastructure/graphql/types'
import { SeriesOpinionQuery } from '~/domain/series-opinion/query'
import type { SeriesOpinion } from '~/domain/series-opinion/types'
import { builder } from '~/domain/shared/graphql/builder'
import { languageOf } from '~/domain/shared/language'
import { Count, Year } from '~/domain/shared/primitives'
import type { AuthorName, Count as CountValue, UserId } from '~/domain/shared/types'

/** A saga the reader follows.
 *
 *  Its identity comes from the reader's own books, not from the catalogue: a
 *  saga named by an Audible import or by a book added by hand has no catalogue
 *  document, and reading the catalogue first made every one of those disappear
 *  from the Series tab.
 *
 *  So `catalogue` is what may be missing, never the saga. */
type FollowedSeries = {
  id: SeriesId
  name: SeriesName
  author?: AuthorName
  language?: BookLanguage
  genre?: Genre
  catalogue: Series | null
  opinion: SeriesOpinion | null
  state: SeriesState | null
  progress: SagaProgress | null
  ownedCount: CountValue
  /** The owned volumes, in the order the saga itself runs. */
  books: Book[]
  /** The latest date any owned volume is shelved on: what the tab is ordered
   *  and cut into month sections by. */
  shelvedAt: Date
}

type SagaProgress = { readCount: number; totalCount: number }

const SagaProgressType = builder.objectRef<SagaProgress>('SagaProgress').implement({
  description:
    'How far the reader is into a saga, on the numbered spine of published volumes: ' +
    'related works and announced volumes are not counted.',
  fields: (t) => ({
    readCount: t.exposeInt('readCount', { description: 'Spine volumes the reader has read' }),
    totalCount: t.exposeInt('totalCount', { description: 'Spine volumes published so far' }),
  }),
})

const FollowedSeriesPageType = builder
  .objectRef<{ items: FollowedSeries[]; hasMore: boolean }>('FollowedSeriesPage')
  .implement({
    description: 'One page of the sagas the reader follows, plus whether more follow it.',
    fields: (t) => ({
      items: t.field({ type: [FollowedSeriesType], resolve: (page) => page.items }),
      hasMore: t.exposeBoolean('hasMore', { description: 'Whether more sagas follow this page' }),
    }),
  })

const FollowedSeriesType = builder.objectRef<FollowedSeries>('FollowedSeries').implement({
  description: 'A saga the reader owns at least one volume of.',
  fields: (t) => ({
    id: t.field({ type: 'SeriesId', resolve: (followed) => followed.id }),
    name: t.field({ type: 'SeriesName', resolve: (followed) => followed.name }),
    author: t.field({
      type: 'AuthorName',
      nullable: true,
      description:
        'The author of a volume the reader owns, which is what answers for a saga ' +
        'the catalogue has never described.',
      resolve: (followed) => followed.author ?? null,
    }),
    language: t.field({
      type: BookLanguageEnum,
      nullable: true,
      description:
        'The language the reader holds these volumes in. A saga held in two ' +
        'languages answers twice, once per language, sharing one `id` — so a ' +
        'client keying rows on the id alone must key on the pair instead.',
      resolve: (followed) => followed.language ?? null,
    }),
    genre: t.field({
      type: GenreEnum,
      nullable: true,
      description: 'The genre most of the owned volumes carry. Null when none of them has one.',
      resolve: (followed) => followed.genre ?? null,
    }),
    catalogue: t.field({
      type: SeriesType,
      nullable: true,
      description:
        'What the world knows of the saga. Null until somebody scans a volume of ' +
        'it or opens it with `series`: an import and a manual entry both name a ' +
        'saga without describing it.',
      resolve: (followed) => followed.catalogue,
    }),
    opinion: t.field({
      type: SeriesOpinionType,
      nullable: true,
      description:
        'What the reader makes of the saga. Null until they say something about ' +
        'it.\n\n' +
        'Held per saga, so the two rows of a saga held in two languages answer ' +
        'with the same opinion: the split is about editions, this is about the work.',
      resolve: (followed) => followed.opinion,
    }),
    state: t.field({
      type: SeriesStateEnum,
      nullable: true,
      description:
        'Derived, never stored. NOT_STARTED while no owned volume has been opened; ' +
        'COMPLETE once every published volume has been read.\n\n' +
        'Without a catalogue, an owned volume still unread makes it IN_PROGRESS. ' +
        'Null when every owned volume is read and there is no catalogue: which ' +
        'volumes exist is exactly what is unknown then, and COMPLETE would be a ' +
        'guess dressed as a fact.',
      resolve: (followed) => followed.state,
    }),
    progress: t.field({
      type: SagaProgressType,
      nullable: true,
      description:
        'How many of the published spine volumes the reader has read. Null without a ' +
        'catalogue, and on a catalogue with no numbered published volume: there is ' +
        'nothing to count against then.',
      resolve: (followed) => followed.progress,
    }),
    ownedCount: t.field({
      type: 'Count',
      description: 'How many volumes of the saga are in the library.',
      resolve: (followed) => followed.ownedCount,
    }),
    shelvedAt: t.field({
      type: 'DateTime',
      description:
        'The latest date any owned volume is shelved on — finished, else started, ' +
        'else added — which the Series tab is ordered and cut into month sections by.',
      resolve: (followed) => followed.shelvedAt,
    }),
    volumes: t.field({
      type: [BookType],
      description:
        'The volumes of the saga in the library, in the order the saga runs: the ' +
        'numbered spine, then what orbits it. What the Series tab draws as a strip ' +
        'of covers.\n\n' +
        'Covers are signed only for the rows that select this field, so a page of ' +
        'the tab pays for the covers it draws and nothing more.',
      resolve: (followed) => BookQuery.withSignedCovers(followed.books),
    }),
  }),
})

builder.queryFields((t) => ({
  series: t.field({
    type: SeriesType,
    nullable: true,
    description:
      'The full catalogue of one saga, owned volumes and unowned alike.\n\n' +
      'Everything the reader does not own is a proposal: nothing enters a library ' +
      'until they add it.\n\n' +
      'Built on first sight when nobody has catalogued the saga yet — an Audible ' +
      'import names sagas without describing them — from the name and author of ' +
      'a volume the reader holds, with one web-grounded model call: the volumes ' +
      'are titled as the edition on the shelf titles them, the rest is written ' +
      'in the language of `Accept-Language`. That first opening takes a few ' +
      'seconds; every later one, by anyone, reads the stored catalogue. Null when ' +
      'the reader holds no volume of the saga, or when the model found nothing ' +
      'to say.',
    args: {
      id: t.arg({ type: 'SeriesId', required: true }),
      language: t.arg({
        type: BookLanguageEnum,
        required: false,
        description:
          'The edition the reader opened, for a saga held in more than one ' +
          'language: a catalogue built on this opening titles its volumes as ' +
          'that edition does. Absent, the edition of whichever volume they hold answers.',
      }),
    },
    resolve: (_root, args, { userId, event }) =>
      SeriesUseCase.describe(userId, args.id, languageOf(event), args.language ?? undefined),
  }),

  mySeriesPage: t.field({
    type: FollowedSeriesPageType,
    description:
      'One page of `mySeries`, for a list that draws as it scrolls: newest first on ' +
      '`shelvedAt`, which the app cuts into month sections as the Library tab does. ' +
      '`favorite` keeps the hearted sagas, `state` one state ' +
      '(COMPLETE also keeps the sagas of unknown state). ' +
      'Offset-paginated: pass the number of rows already shown.',
    args: {
      limit: t.arg.int({ defaultValue: 40, description: 'Maximum sagas in the page' }),
      offset: t.arg.int({ defaultValue: 0, description: 'Rows to skip' }),
      favorite: t.arg.boolean({ required: false, description: 'Only the hearted sagas' }),
      state: t.arg({ type: SeriesStateEnum, required: false }),
    },
    resolve: async (_root, args, context) => {
      const followed = (await followedSeriesOf(context.userId)).map((saga) => ({
        ...saga,
        favorite: saga.opinion?.favorite === true,
      }))
      const kept = matchingFilter(followed, {
        favorite: args.favorite ?? undefined,
        state: args.state ?? undefined,
      })
      const rows = inTabOrder(kept)
      const limit = Math.max(1, Math.min(args.limit ?? 40, 200))
      const offset = Math.max(0, args.offset ?? 0)
      return { items: rows.slice(offset, offset + limit), hasMore: offset + limit < rows.length }
    },
  }),

  mySeries: t.field({
    type: [FollowedSeriesType],
    description:
      'Every saga the reader owns a volume of, alphabetically.\n\n' +
      'Taken from the books, then matched against the catalogue in one getAll ' +
      'rather than a lookup per saga. A saga nobody has catalogued still answers ' +
      'here, with a null catalogue and a null state.\n\n' +
      'One row per saga and language: a reader who holds Dune in French and in ' +
      'English follows two rows, because those are two sets of books.',
    resolve: (_root, _args, context) => followedSeriesOf(context.userId),
  }),
}))

/** Every saga the reader follows, one row per saga and language: what both
 *  the whole list and a page of it are cut from. */
const followedSeriesOf = async (userId: UserId): Promise<FollowedSeries[]> => {
  const sagas = followedSagasOf(await BookQuery.all(userId))
  // One scan of the reader's opinions for the whole tab, rather than a
  // lookup per row: a reader with forty sagas would otherwise pay forty.
  const opinions = new Map(
    (await SeriesOpinionQuery.all(userId)).map((opinion) => [opinion.seriesId, opinion]),
  )
  const catalogued = new Map(
    (await SeriesQuery.byIds(sagas.map((saga) => saga.id))).map((series) => [series.id, series]),
  )
  const currentYear = Year(new Date().getUTCFullYear())
  return sagas.map((saga) => {
    const catalogue = catalogued.get(saga.id) ?? null
    const read = readVolumeNumbersOf(saga.books)
    return {
      id: saga.id,
      name: saga.name,
      author: saga.author,
      language: saga.language,
      genre: genreOf(saga.books),
      catalogue,
      opinion: opinions.get(saga.id) ?? null,
      state: followedStateOf(
        saga.books.map((book) => book.status),
        catalogue,
        read,
        currentYear,
      ),
      progress: catalogue ? progressOf(catalogue, read, currentYear) : null,
      ownedCount: Count(saga.books.length),
      books: inSagaOrder(saga.books),
      shelvedAt: new Date(Math.max(...saga.books.map((book) => shelfDateOf(book).getTime()))),
    }
  })
}

const inSagaOrder = (books: readonly Book[]): Book[] =>
  [...books].sort((left, right) =>
    compareWithinSeries(
      { kind: left.series?.kind ?? 'main', number: left.series?.volume, title: left.title },
      { kind: right.series?.kind ?? 'main', number: right.series?.volume, title: right.title },
    ),
  )
