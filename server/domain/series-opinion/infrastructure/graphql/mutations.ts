import { SeriesOpinionType } from '~/domain/series-opinion/infrastructure/graphql/types'
import { SeriesOpinionUseCase } from '~/domain/series-opinion/use-case'
import { builder } from '~/domain/shared/graphql/builder'

builder.mutationFields((t) => ({
  rateSeries: t.field({
    type: SeriesOpinionType,
    description:
      'Rate a saga, one to five stars. Its own judgement, not the average of the ' +
      'volumes, and it leaves every volume rating alone.\n\n' +
      'The saga is not checked to exist: a reader reaches it from a volume they ' +
      'own, and a saga the catalogue has never described is still theirs to rate.',
    args: {
      seriesId: t.arg({ type: 'SeriesId', required: true }),
      rating: t.arg({ type: 'StarRating', required: true }),
    },
    resolve: (_root, args, context) =>
      SeriesOpinionUseCase.rate(context.userId, args.seriesId, args.rating),
  }),

  removeSeriesRating: t.field({
    type: SeriesOpinionType,
    description: 'Take a saga rating back. Leaves the heart alone.',
    args: { seriesId: t.arg({ type: 'SeriesId', required: true }) },
    resolve: (_root, args, context) =>
      SeriesOpinionUseCase.rate(context.userId, args.seriesId, undefined),
  }),

  setSeriesFavorite: t.field({
    type: SeriesOpinionType,
    description: 'Keep a saga close, or stop. Leaves the rating alone.',
    args: {
      seriesId: t.arg({ type: 'SeriesId', required: true }),
      favorite: t.arg.boolean({ required: true }),
    },
    resolve: (_root, args, context) =>
      SeriesOpinionUseCase.setFavorite(context.userId, args.seriesId, args.favorite),
  }),
}))
