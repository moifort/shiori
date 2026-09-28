import { match, P } from 'ts-pattern'
import { BookLanguageEnum } from '~/domain/book/infrastructure/graphql/enums'
import {
  AnnouncedVolumePreviewType,
  DiscoveryType,
  ReleaseFormatEnum,
  SagaReleasesType,
} from '~/domain/discovery/infrastructure/graphql/types'
import { DiscoveryUseCase } from '~/domain/discovery/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { domainError, notFound } from '~/domain/shared/graphql/errors'
import { languageOf } from '~/domain/shared/language'

builder.mutationFields((t) => ({
  lookUpDiscovery: t.field({
    type: DiscoveryType,
    description:
      'Look up now, on the web, every saga, then every author, the reader follows in that ' +
      'format that was never looked up, rather than wait for the hourly pass — for the first look at the ' +
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
  previewAnnouncedVolume: t.field({
    type: AnnouncedVolumePreviewType,
    description:
      'Describe a volume the release watch announced, for its page before the reader adds ' +
      'it. A printed volume is described by the web-grounded model; a recording Audible ' +
      'confirmed is read off Audible’s catalogue first, and the model adds its summary, ' +
      'genre and first publication. A few seconds. Nothing is saved.\n\n' +
      'Spends one scan of the allowance, as a typed title does. Fails with `NOT_FOUND` for ' +
      'a volume no watch announced in that edition, `QUOTA_EXHAUSTED` once nothing is left, ' +
      'or `SCAN_FAILED` when the model call errors.',
    deprecationReason:
      'The volume page draws what `discovery` already carries, with no model call.',
    args: {
      seriesId: t.arg({ type: 'SeriesId', required: true }),
      language: t.arg({ type: BookLanguageEnum, required: true }),
      number: t.arg({ type: 'VolumeNumber', required: true }),
    },
    resolve: async (_root, { seriesId, language, number }, context) =>
      match(
        await DiscoveryUseCase.previewAnnouncedVolume(
          context.userId,
          { seriesId, language, number },
          languageOf(context.event),
        ),
      )
        .with('not-found', () => notFound('No such volume announced'))
        .with('quota-exhausted', () => domainError('QUOTA_EXHAUSTED', 'Scan allowance is used up'))
        .with({ failed: P.string }, ({ failed }) => domainError('SCAN_FAILED', failed))
        .with({ book: P.any }, (preview) => preview)
        .exhaustive(),
  }),
}))
