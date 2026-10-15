import { builder } from '~/domain/shared/graphql/builder'
import { notFound } from '~/domain/shared/graphql/errors'
import { SuggestionUseCase } from '~/domain/suggestion/use-case'

builder.mutationFields((t) => ({
  dismissSuggestion: t.boolean({
    description:
      '"Pas intéressé": the suggestion leaves the discoveries for good, and the model is ' +
      'told not to suggest it again. `NOT_FOUND` when the reader has no such suggestion.',
    args: { id: t.arg.string({ required: true }) },
    resolve: async (_root, { id }, context) => {
      const outcome = await SuggestionUseCase.dismiss(context.userId, id)
      if (outcome === 'not-found') return notFound('No such suggestion')
      return true
    },
  }),
}))
