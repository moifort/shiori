import { readVolumeNumbersOf } from '~/domain/book/business-rules'
import { BookQuery } from '~/domain/book/query'
import { followedSagasOf, stateOf } from '~/domain/series/business-rules'
import { SeriesStateEnum } from '~/domain/series/infrastructure/graphql/enums'
import { SeriesType } from '~/domain/series/infrastructure/graphql/types'
import { SeriesQuery } from '~/domain/series/query'
import type { Series, SeriesId, SeriesName, SeriesState } from '~/domain/series/types'
import { builder } from '~/domain/shared/graphql/builder'
import { Count, Year } from '~/domain/shared/primitives'
import type { AuthorName, Count as CountValue } from '~/domain/shared/types'

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
  catalogue: Series | null
  state: SeriesState | null
  ownedCount: CountValue
}

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
    catalogue: t.field({
      type: SeriesType,
      nullable: true,
      description:
        'What the world knows of the saga. Null until somebody scans a volume of ' +
        'it: an import and a manual entry both name a saga without describing it.',
      resolve: (followed) => followed.catalogue,
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
      'until they add it. Null when the saga has never been catalogued.',
    args: { id: t.arg({ type: 'SeriesId', required: true }) },
    resolve: (_root, args) => SeriesQuery.byId(args.id),
  }),

  mySeries: t.field({
    type: [FollowedSeriesType],
    description:
      'Every saga the reader owns a volume of, alphabetically.\n\n' +
      'Taken from the books, then matched against the catalogue in one getAll ' +
      'rather than a lookup per saga. A saga nobody has catalogued still answers ' +
      'here, with a null catalogue and a null state.',
    resolve: async (_root, _args, context) => {
      const sagas = followedSagasOf(await BookQuery.all(context.userId))
      const catalogued = new Map(
        (await SeriesQuery.byIds(sagas.map((saga) => saga.id))).map((series) => [
          series.id,
          series,
        ]),
      )
      const currentYear = Year(new Date().getUTCFullYear())
      return sagas.map((saga) => {
        const catalogue = catalogued.get(saga.id) ?? null
        return {
          id: saga.id,
          name: saga.name,
          author: saga.author,
          catalogue,
          state: catalogue
            ? stateOf(catalogue, readVolumeNumbersOf(saga.books), currentYear)
            : null,
          ownedCount: Count(saga.books.length),
        }
      })
    },
  }),
}))
