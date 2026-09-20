import { SeriesOpinionType } from '~/domain/series-opinion/infrastructure/graphql/types'
import { SeriesOpinionQuery } from '~/domain/series-opinion/query'
import { builder } from '~/domain/shared/graphql/builder'

builder.queryFields((t) => ({
  seriesOpinion: t.field({
    type: SeriesOpinionType,
    nullable: true,
    description:
      'What the reader makes of one saga. Null until they say something about ' +
      'it — an opinion with neither a rating nor a heart is not stored.\n\n' +
      'A root query rather than a field on `Series`: the catalogue holds no ' +
      'reference to any reader, and it must stay that way.',
    args: { seriesId: t.arg({ type: 'SeriesId', required: true }) },
    resolve: (_root, args, context) => SeriesOpinionQuery.of(context.userId, args.seriesId),
  }),
}))
