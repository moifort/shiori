import { AwardUseCase } from '~/domain/award/use-case'
import { builder } from '~/domain/shared/graphql/builder'

builder.mutationFields((t) => ({
  dismissAwardWinner: t.boolean({
    description:
      '"Pas intéressé" on an award winner: it leaves the reader’s lists, in every format, ' +
      'until `reconsiderAwardWinner`.',
    args: { key: t.arg.string({ required: true, description: '`AwardWinner.key`.' }) },
    resolve: async (_root, { key }, context) => {
      await AwardUseCase.dismiss(context.userId, key)
      return true
    },
  }),
  reconsiderAwardWinner: t.boolean({
    description: 'A dismissal taken back: the winner is listed again.',
    args: { key: t.arg.string({ required: true, description: '`AwardWinner.key`.' }) },
    resolve: async (_root, { key }, context) => {
      await AwardUseCase.reconsider(context.userId, key)
      return true
    },
  }),
}))
