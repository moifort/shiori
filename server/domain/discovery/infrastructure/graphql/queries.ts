import { BookLanguageEnum } from '~/domain/book/infrastructure/graphql/enums'
import {
  DiscoveryType,
  ReleaseFormatEnum,
  SagaReleasesType,
} from '~/domain/discovery/infrastructure/graphql/types'
import { DiscoveryUseCase } from '~/domain/discovery/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { languageOf } from '~/domain/shared/language'

builder.queryFields((t) => ({
  discovery: t.field({
    type: DiscoveryType,
    description:
      'The Découvrir tab: every saga the reader follows in that format — all but the ones ' +
      'they set aside — with the next volume announced they do not hold, the soonest ' +
      'first; a saga with nothing announced is left out.\n\n' +
      'Read off shared watches a scheduled pass keeps a week fresh, so it answers at once. ' +
      'A saga never looked up is counted in `unwatched`, for `lookUpDiscovery`.',
    args: { format: t.arg({ type: ReleaseFormatEnum, required: true }) },
    resolve: (_root, { format }, context) =>
      DiscoveryUseCase.discover(context.userId, languageOf(context.event), format),
  }),
  sagaReleases: t.field({
    type: SagaReleasesType,
    description:
      'What the saga screen shows under its introduction: the next volume announced the ' +
      'reader does not hold, in the edition they opened. Empty, and not ' +
      '`watched`, for an edition nobody looked up yet: `lookUpSagaReleases` does.',
    args: {
      seriesId: t.arg({ type: 'SeriesId', required: true }),
      language: t.arg({ type: BookLanguageEnum, required: true }),
    },
    resolve: (_root, { seriesId, language }, context) =>
      DiscoveryUseCase.sagaReleases(context.userId, seriesId, language),
  }),
}))
