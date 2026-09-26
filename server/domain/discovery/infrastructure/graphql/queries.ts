import { BookLanguageEnum } from '~/domain/book/infrastructure/graphql/enums'
import {
  ReleaseFormatEnum,
  SagaDiscoveryType,
  SagaReleasesType,
} from '~/domain/discovery/infrastructure/graphql/types'
import { DiscoveryUseCase } from '~/domain/discovery/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { languageOf } from '~/domain/shared/language'

builder.queryFields((t) => ({
  discovery: t.field({
    type: [SagaDiscoveryType],
    description:
      'The Découvrir tab: every saga the reader follows in that format — all but the ones ' +
      'they set aside — with the volumes out they do not hold and the next one announced. ' +
      'Sagas with volumes to get come first, then those with only an announcement, the ' +
      'soonest first; a saga with neither is left out.\n\n' +
      'Read off shared watches a scheduled pass keeps a week fresh, so it answers at once. ' +
      'A saga followed since the last pass is looked up within the hour.',
    args: { format: t.arg({ type: ReleaseFormatEnum, required: true }) },
    resolve: (_root, { format }, context) =>
      DiscoveryUseCase.discover(context.userId, languageOf(context.event), format),
  }),
  sagaReleases: t.field({
    type: SagaReleasesType,
    description:
      'What the saga screen shows under its introduction: the volumes out the reader does ' +
      'not hold, and the next one announced, in the edition they opened. Empty for an ' +
      'edition nobody watched yet.',
    args: {
      seriesId: t.arg({ type: 'SeriesId', required: true }),
      language: t.arg({ type: BookLanguageEnum, required: true }),
    },
    resolve: (_root, { seriesId, language }, context) =>
      DiscoveryUseCase.sagaReleases(context.userId, seriesId, language),
  }),
}))
