import { BookLanguageEnum } from '~/domain/book/infrastructure/graphql/enums'
import { DEPRECATED_EDITION_LANGUAGE } from '~/domain/series/infrastructure/graphql/types'
import { seriesReferenceOf } from '~/domain/series/primitives'
import type { SeriesId } from '~/domain/series/types'
import { SeriesOpinionType } from '~/domain/series-opinion/infrastructure/graphql/types'
import { SeriesOpinionUseCase } from '~/domain/series-opinion/use-case'
import { builder } from '~/domain/shared/graphql/builder'

/** The saga an opinion is of: the work, whichever edition the reader rates it
 *  from. */
const sagaOf = (id: SeriesId) => seriesReferenceOf(id).saga

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
      SeriesOpinionUseCase.rate(context.userId, sagaOf(args.seriesId), args.rating),
  }),

  removeSeriesRating: t.field({
    type: SeriesOpinionType,
    description: 'Take a saga rating back. Leaves the heart alone.',
    args: { seriesId: t.arg({ type: 'SeriesId', required: true }) },
    resolve: (_root, args, context) =>
      SeriesOpinionUseCase.rate(context.userId, sagaOf(args.seriesId), undefined),
  }),

  declareSeriesVolumeCount: t.field({
    type: SeriesOpinionType,
    description:
      'Say how many volumes a saga has, for a saga nobody has catalogued: `series` ' +
      'then answers with a provisional catalogue drawn from the count — the ' +
      "reader's volumes at their numbers, the saga's name standing in for the " +
      'rest — and the Series tab and the dashboard measure the saga against it.\n\n' +
      "Kept on the reader's own opinion, never written into the shared catalogue: " +
      'a count typed by one reader is not a fact about the world. It stops ' +
      'mattering the day a catalogue exists — a scan of one of its volumes, or ' +
      '`refreshSeries`, builds one.',
    args: {
      seriesId: t.arg({ type: 'SeriesId', required: true }),
      count: t.arg({
        type: 'VolumeNumber',
        required: true,
        description: 'The number the last volume carries.',
      }),
    },
    resolve: (_root, args, context) =>
      SeriesOpinionUseCase.declareVolumeCount(context.userId, sagaOf(args.seriesId), args.count),
  }),

  setSeriesFollowed: t.field({
    type: SeriesOpinionType,
    description:
      'Set a saga aside, or follow it again. A saga the reader stopped following ' +
      'is `UNFOLLOWED` whatever its volumes say: out of the sagas in progress and ' +
      'of the finished ones, off the dashboard progress bars, and listed only ' +
      'under its own state filter. Only the saga — its volumes keep their own ' +
      'statuses. Leaves the rating and the heart alone.\n\n' +
      'Only the edition `seriesId` names moves: setting the English Dune aside ' +
      'leaves the French one followed. A bare saga key, from an older build, moves ' +
      'the whole saga, every edition at once — or the one `language` names.',
    args: {
      seriesId: t.arg({ type: 'SeriesId', required: true }),
      followed: t.arg.boolean({ required: true }),
      language: t.arg({
        type: BookLanguageEnum,
        required: false,
        description: 'Beside a bare saga key: the one edition to move.',
        deprecationReason: DEPRECATED_EDITION_LANGUAGE,
      }),
    },
    resolve: (_root, args, context) => {
      const { saga, language } = seriesReferenceOf(args.seriesId, args.language ?? undefined)
      return SeriesOpinionUseCase.setFollowed(context.userId, saga, args.followed, language)
    },
  }),

  setSeriesFavorite: t.field({
    type: SeriesOpinionType,
    description: 'Keep a saga close, or stop. Leaves the rating alone.',
    args: {
      seriesId: t.arg({ type: 'SeriesId', required: true }),
      favorite: t.arg.boolean({ required: true }),
    },
    resolve: (_root, args, context) =>
      SeriesOpinionUseCase.setFavorite(context.userId, sagaOf(args.seriesId), args.favorite),
  }),
}))
