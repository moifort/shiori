import { readVolumeNumbersOf } from '~/domain/book/business-rules'
import { BookQuery } from '~/domain/book/query'
import { stateOf } from '~/domain/series/business-rules'
import { SeriesStateEnum } from '~/domain/series/infrastructure/graphql/enums'
import { SeriesType } from '~/domain/series/infrastructure/graphql/types'
import { SeriesQuery } from '~/domain/series/query'
import type { Series, SeriesId, SeriesState } from '~/domain/series/types'
import { builder } from '~/domain/shared/graphql/builder'
import { Count, Year } from '~/domain/shared/primitives'
import type { Count as CountValue } from '~/domain/shared/types'

/** A saga the reader follows, with the state derived from what they own. The
 *  catalogue itself knows nothing about readers, so the pairing happens here. */
type FollowedSeries = { series: Series; state: SeriesState; ownedCount: CountValue }

const FollowedSeriesType = builder.objectRef<FollowedSeries>('FollowedSeries').implement({
  description: 'A saga the reader owns at least one volume of.',
  fields: (t) => ({
    series: t.field({ type: SeriesType, resolve: (followed) => followed.series }),
    state: t.field({
      type: SeriesStateEnum,
      description: 'Derived, never stored. COMPLETE once every published volume has been read.',
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
      'Resolved in one getAll over the catalogue rather than a lookup per saga.',
    resolve: async (_root, _args, context) => {
      const books = await BookQuery.all(context.userId)
      const seriesIds = [
        ...new Set(books.map((book) => book.series?.id).filter((id): id is SeriesId => !!id)),
      ]
      const catalogued = await SeriesQuery.byIds(seriesIds)
      const currentYear = Year(new Date().getUTCFullYear())
      return catalogued
        .map((series) => {
          const owned = books.filter((book) => book.series?.id === series.id)
          return {
            series,
            state: stateOf(series, readVolumeNumbersOf(owned), currentYear),
            ownedCount: Count(owned.length),
          }
        })
        .sort((left, right) => left.series.name.localeCompare(right.series.name))
    },
  }),
}))
