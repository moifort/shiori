import { BookLanguageEnum } from '~/domain/book/infrastructure/graphql/enums'
import {
  DiscoveryType,
  ReleaseFormatEnum,
  SagaReleasesType,
} from '~/domain/discovery/infrastructure/graphql/types'
import { DiscoveryUseCase } from '~/domain/discovery/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { languageOf } from '~/domain/shared/language'

builder.mutationFields((t) => ({
  lookUpDiscovery: t.field({
    type: DiscoveryType,
    description:
      'Look up now, on the web, every saga the reader follows in that format that was ' +
      'never looked up, rather than wait for the hourly pass — for the first look at the ' +
      'tab, and a saga followed since. Slow: grounded model calls, a few side by side, up ' +
      'to about ninety seconds; whatever is left goes to the hourly pass. Answers the tab.',
    args: { format: t.arg({ type: ReleaseFormatEnum, required: true }) },
    resolve: (_root, { format }, context) =>
      DiscoveryUseCase.lookUpUnwatched(context.userId, languageOf(context.event), format),
  }),
  lookUpSagaReleases: t.field({
    type: SagaReleasesType,
    description:
      'Look a saga up on the web now in the edition opened, when nobody ever did — one ' +
      'grounded call, about ten seconds — and answer what it has for the reader. An ' +
      'edition already looked up is answered as it stands.',
    args: {
      seriesId: t.arg({ type: 'SeriesId', required: true }),
      language: t.arg({ type: BookLanguageEnum, required: true }),
    },
    resolve: (_root, { seriesId, language }, context) =>
      DiscoveryUseCase.lookUpSaga(context.userId, seriesId, language),
  }),
}))
