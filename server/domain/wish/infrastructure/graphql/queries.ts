import { AwaitedEditionUseCase } from '~/domain/awaited-edition/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { WishlistType } from '~/domain/wish/infrastructure/graphql/types'
import { WishUseCase } from '~/domain/wish/use-case'

builder.queryFields((t) => ({
  wishlist: t.field({
    type: WishlistType,
    description:
      'The reader’s wishlist: the books wished for and the editions awaited. Neither ' +
      'one the library now holds — they go on their own. Read off the reader’s own ' +
      'documents and the shared release watches: no web lookup.',
    resolve: async (_root, _args, context) => {
      const [wishes, awaited] = await Promise.all([
        WishUseCase.wishes(context.userId),
        AwaitedEditionUseCase.everyAwaited(context.userId),
      ])
      return { wishes, awaited }
    },
  }),
}))
