import { NarratorCommand } from '~/domain/narrator/command'
import { builder } from '~/domain/shared/graphql/builder'

builder.mutationFields((t) => ({
  setNarratorFavorite: t.boolean({
    description:
      'Heart a narrator, or take the heart back: the reader’s own, apart from the ' +
      'hearts their recordings carry, never shared. Answers what is now true. One write.',
    args: {
      key: t.arg({ type: 'NarratorKey', required: true }),
      favorite: t.arg.boolean({ required: true, description: 'True hearts, false takes it back' }),
    },
    resolve: (_root, args, { userId }) =>
      NarratorCommand.setFavorite(userId, args.key, args.favorite),
  }),
}))
