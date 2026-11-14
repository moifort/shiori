import { match, P } from 'ts-pattern'
import { AwaitedEditionUseCase } from '~/domain/awaited-edition/use-case'
import { AwardUseCase } from '~/domain/award/use-case'
import { ReleaseFormatEnum } from '~/domain/discovery/infrastructure/graphql/types'
import { DiscoveryUseCase } from '~/domain/discovery/use-case'
import { ReleaseType } from '~/domain/release/infrastructure/graphql/types'
import type { ReleaseView } from '~/domain/release/types'
import type { DescribeRefusal } from '~/domain/release/use-case'
import { seriesReferenceOf } from '~/domain/series/primitives'
import { builder } from '~/domain/shared/graphql/builder'
import { aiUnavailable, badUserInput, domainError, notFound } from '~/domain/shared/graphql/errors'
import { languageOf } from '~/domain/shared/language'
import { SuggestionUseCase } from '~/domain/suggestion/use-case'

const AwardWinnerReleaseInput = builder.inputType('AwardWinnerReleaseInput', {
  description: 'An award winner’s edition in one format.',
  fields: (t) => ({
    key: t.string({ required: true, description: 'The novel: `AwardWinner.key`.' }),
    format: t.field({ type: ReleaseFormatEnum, required: true }),
  }),
})

const SuggestionReleaseInput = builder.inputType('SuggestionReleaseInput', {
  description: 'One of the month’s discoveries, in one format.',
  fields: (t) => ({
    id: t.string({ required: true, description: '`Suggestion.id`.' }),
    format: t.field({ type: ReleaseFormatEnum, required: true }),
  }),
})

const SagaVolumeReleaseInput = builder.inputType('SagaVolumeReleaseInput', {
  description: 'A volume a saga’s watch announced, in the edition shown.',
  fields: (t) => ({
    seriesId: t.field({ type: 'SeriesId', required: true }),
    number: t.field({ type: 'VolumeNumber', required: true }),
  }),
})

const ReleaseItemInput = builder.inputType('ReleaseItemInput', {
  description:
    'What a list showed the release as, exactly one of: an edition the reader awaits, an ' +
    'award winner, a discovery, a saga’s volume. The server knows the release from it; the ' +
    'device sends nothing of the book.',
  fields: (t) => ({
    awaitedEditionId: t.field({ type: 'AwaitedEditionId', required: false }),
    awardWinner: t.field({ type: AwardWinnerReleaseInput, required: false }),
    suggestion: t.field({ type: SuggestionReleaseInput, required: false }),
    sagaVolume: t.field({ type: SagaVolumeReleaseInput, required: false }),
  }),
})

const answered = (outcome: ReleaseView | DescribeRefusal | 'not-found') =>
  match(outcome)
    .with('not-found', () => notFound('No such release among what the reader is shown'))
    .with('quota-exhausted', () => domainError('QUOTA_EXHAUSTED', 'Scan allowance is used up'))
    .with('ai-unavailable', aiUnavailable)
    .with({ failed: P.string }, ({ failed }) => domainError('SCAN_FAILED', failed))
    .with({ key: P.string }, (view) => view)
    .exhaustive()

builder.mutationFields((t) => ({
  describeReleaseOf: t.field({
    type: ReleaseType,
    description:
      'Describe for its page a book a list shows — an edition awaited, an award winner, a ' +
      'discovery, a saga’s volume — as a scan describes one: the web-grounded model fills in ' +
      'its summary, genre, pages and publisher, and Audible the narrators and running time ' +
      'of a recording. About ten seconds the first time. Answers the release as every list ' +
      'and its page now draw it.\n\n' +
      'Kept in the release for every reader, for sixty days: the call is paid once and ' +
      'spends nobody’s scan. Refused with `QUOTA_EXHAUSTED` when the reader’s allowance is ' +
      'used up and nobody described it yet, `SCAN_FAILED` (`AI_UNAVAILABLE` while the AI is ' +
      'out of credit) when the model call errors, `NOT_FOUND` for a release the reader is ' +
      'not shown.',
    args: { item: t.arg({ type: ReleaseItemInput, required: true }) },
    resolve: async (_root, { item }, context) => {
      const language = languageOf(context.event)
      const named = [item.awaitedEditionId, item.awardWinner, item.suggestion, item.sagaVolume]
      if (named.filter((one) => one != null).length !== 1)
        return badUserInput('Name exactly one item')
      if (item.awaitedEditionId)
        return answered(
          await AwaitedEditionUseCase.describe(context.userId, item.awaitedEditionId, language),
        )
      if (item.awardWinner)
        return answered(
          await AwardUseCase.describe(
            context.userId,
            item.awardWinner.key,
            item.awardWinner.format,
            language,
          ),
        )
      if (item.suggestion)
        return answered(
          await SuggestionUseCase.describe(
            context.userId,
            item.suggestion.id,
            item.suggestion.format,
            language,
          ),
        )
      const volume = item.sagaVolume
      if (!volume) return badUserInput('Name exactly one item')
      const { saga, language: edition } = seriesReferenceOf(volume.seriesId)
      if (!edition) return badUserInput('The series id names no edition')
      return answered(
        await DiscoveryUseCase.describeVolume(
          context.userId,
          { seriesId: saga, language: edition, number: volume.number },
          language,
        ),
      )
    },
  }),
}))
