import { readVolumeNumbersOf } from '~/domain/book/business-rules'
import { BookLanguageEnum } from '~/domain/book/infrastructure/graphql/enums'
import { BookQuery } from '~/domain/book/query'
import type { BookLanguage } from '~/domain/book/types'
import { followedSagasOf, stateOf } from '~/domain/series/business-rules'
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
  catalogue: Series | null
  opinion: SeriesOpinion | null
  state: SeriesState | null
  ownedCount: CountValue
}

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
        'Derived, never stored. COMPLETE once every published volume has been read.\n\n' +
        'Null without a catalogue: which volumes exist is exactly what is unknown ' +
        'then, and IN_PROGRESS would be a guess dressed as a fact.',
      resolve: (followed) => followed.state,
    }),
    ownedCount: t.field({
      type: 'Count',
      description: 'How many volumes of the saga are in the library.',
      resolve: (followed) => followed.ownedCount,
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
      'a volume the reader holds, with one web-grounded model call in the ' +
      'language of `Accept-Language`. That first opening takes a few seconds; ' +
      'every later one, by anyone, reads the stored catalogue. Null when the ' +
      'reader holds no volume of the saga, or when the model found nothing to say.',
    args: { id: t.arg({ type: 'SeriesId', required: true }) },
    resolve: (_root, args, { userId, event }) =>
      SeriesUseCase.describe(userId, args.id, languageOf(event)),
  }),

  mySeriesPage: t.field({
    type: FollowedSeriesPageType,
    description:
      'One page of `mySeries`, in the same order, for a list that draws as it ' +
      'scrolls. Offset-paginated: pass the number of rows already shown.',
    args: {
      limit: t.arg.int({ defaultValue: 40, description: 'Maximum sagas in the page' }),
      offset: t.arg.int({ defaultValue: 0, description: 'Rows to skip' }),
    },
    resolve: async (_root, args, context) => {
      const rows = await followedSeriesOf(context.userId)
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
    return {
      id: saga.id,
      name: saga.name,
      author: saga.author,
      language: saga.language,
      catalogue,
      opinion: opinions.get(saga.id) ?? null,
      state: catalogue ? stateOf(catalogue, readVolumeNumbersOf(saga.books), currentYear) : null,
      ownedCount: Count(saga.books.length),
    }
  })
}
