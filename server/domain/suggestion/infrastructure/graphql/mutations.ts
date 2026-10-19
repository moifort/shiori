import { builder } from '~/domain/shared/graphql/builder'
import { notFound } from '~/domain/shared/graphql/errors'
import { DismissalReasonEnum } from '~/domain/suggestion/infrastructure/graphql/types'
import { SuggestionUseCase } from '~/domain/suggestion/use-case'

builder.mutationFields((t) => ({
  dismissSuggestion: t.boolean({
    description:
      '"Pas intéressé" or "Je n’aime pas": the suggestion leaves the discoveries for good, and ' +
      'the model is told why next month. `NOT_FOUND` when the reader has no such suggestion.',
    args: {
      id: t.arg.string({ required: true }),
      reason: t.arg({
        type: DismissalReasonEnum,
        required: true,
        defaultValue: 'not-interested',
        description: 'Why; "Pas intéressé" when left out, as builds before it ask.',
      }),
    },
    resolve: async (_root, { id, reason }, context) => {
      const outcome = await SuggestionUseCase.dismiss(context.userId, id, reason)
      if (outcome === 'not-found') return notFound('No such suggestion')
      return true
    },
  }),
}))
