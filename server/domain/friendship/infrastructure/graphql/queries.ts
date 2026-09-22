import {
  FriendBookType,
  FriendProfileType,
  FriendType,
} from '~/domain/friendship/infrastructure/graphql/types'
import { FriendshipUseCase } from '~/domain/friendship/use-case'
import { builder } from '~/domain/shared/graphql/builder'

builder.queryFields((t) => ({
  friends: t.field({
    type: [FriendType],
    description:
      'Everybody the reader shares libraries with, by first name.\n\n' +
      "Friendship is symmetric: each of these can see the reader's shelf on " +
      'the same terms. Their books are a separate read — a list of six friends ' +
      'must not fetch six libraries.',
    resolve: (_root, _args, context) => FriendshipUseCase.friends(context.userId),
  }),

  friendProfile: t.field({
    type: FriendProfileType,
    nullable: true,
    description:
      "One friend's shelf: what they are reading, their pile, their favourites " +
      'and the sagas they are working through.\n\n' +
      'Null for anybody the reader is not friends with, which is also the answer ' +
      'for an id that names nobody: a stranger must not be able to tell an ' +
      'account that refused them from one that does not exist.\n\n' +
      'A book marked "do not share" appears nowhere here, and no reading note is ' +
      'exposed at all.',
    args: { userId: t.arg({ type: 'UserId', required: true }) },
    resolve: async (_root, args, context) => {
      const profile = await FriendshipUseCase.profile(context.userId, args.userId)
      return profile === 'not-friends' ? null : profile
    },
  }),

  myShelf: t.field({
    type: FriendProfileType,
    description:
      "The reader's own shelf exactly as their friends see it: the same lists, " +
      'the same order, the books marked "do not share" left out. Uncut, where a ' +
      "friend's view stops at thirty of each.",
    resolve: (_root, _args, context) => FriendshipUseCase.ownShelf(context.userId),
  }),

  friendBook: t.field({
    type: FriendBookType,
    nullable: true,
    description:
      "One book of a friend's shelf, for the read-only page a row opens.\n\n" +
      'Null for a stranger, a book that does not exist and a book marked "do ' +
      'not share" alike — none of the three may be told apart.',
    args: {
      userId: t.arg({ type: 'UserId', required: true, description: 'The friend' }),
      bookId: t.arg({ type: 'BookId', required: true }),
    },
    resolve: (_root, args, context) =>
      FriendshipUseCase.book(context.userId, args.userId, args.bookId),
  }),
}))
