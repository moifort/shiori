import { ReadingStatusEnum } from '~/domain/book/infrastructure/graphql/enums'
import {
  FriendBookType,
  FriendLibraryPageType,
  FriendProfileType,
  FriendSagaPageType,
  FriendType,
} from '~/domain/friendship/infrastructure/graphql/types'
import { FriendshipUseCase } from '~/domain/friendship/use-case'
import { SeriesStateEnum } from '~/domain/series/infrastructure/graphql/enums'
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
      "One book of a friend's shelf, for the read-only page a row opens — or " +
      "of the reader's own, previewing what their friends are shown.\n\n" +
      'Null for a stranger, a book that does not exist and a book marked "do ' +
      'not share" alike — none of the three may be told apart.',
    args: {
      userId: t.arg({ type: 'UserId', required: true, description: 'The friend' }),
      bookId: t.arg({ type: 'BookId', required: true }),
    },
    resolve: (_root, args, context) =>
      FriendshipUseCase.book(context.userId, args.userId, args.bookId),
  }),

  friendLibraryPage: t.field({
    type: FriendLibraryPageType,
    nullable: true,
    description:
      "One page of a friend's library — or of the reader's own, previewing what " +
      "their friends are shown — drawn as the Library tab draws the reader's: " +
      'newest first on `shelvedAt`, the dropped books left out unless asked for. ' +
      'A book marked "do not share" never appears. Null for a stranger.',
    args: {
      userId: t.arg({ type: 'UserId', required: true, description: 'The friend' }),
      status: t.arg({
        type: ReadingStatusEnum,
        required: false,
        description: 'Keep only books in this status. Omit for the whole library.',
      }),
      favorite: t.arg.boolean({
        required: false,
        description: 'Keep only the books they hearted.',
      }),
      limit: t.arg.int({ defaultValue: 60, description: 'Maximum books in the page' }),
      after: t.arg({
        type: 'BookId',
        required: false,
        description: 'Cursor: the last book of the previous page',
      }),
    },
    resolve: (_root, args, context) =>
      FriendshipUseCase.libraryPage(
        context.userId,
        args.userId,
        { limit: Math.max(1, Math.min(args.limit ?? 60, 200)), after: args.after ?? undefined },
        { status: args.status ?? undefined, favorite: args.favorite ?? undefined },
      ),
  }),

  friendSagaPage: t.field({
    type: FriendSagaPageType,
    nullable: true,
    description:
      "One page of a friend's sagas — or of the reader's own, previewed — drawn " +
      "as the Series tab draws the reader's: the saga shelved last first, every " +
      'volume on the shelf as a cover. Null for a stranger.',
    args: {
      userId: t.arg({ type: 'UserId', required: true, description: 'The friend' }),
      state: t.arg({
        type: SeriesStateEnum,
        required: false,
        description: 'Keep only the sagas where they stand so. Omit for all of them.',
      }),
      favorite: t.arg.boolean({
        required: false,
        description: 'Keep only the sagas they hearted.',
      }),
      limit: t.arg.int({ defaultValue: 30, description: 'Maximum sagas in the page' }),
      after: t.arg.string({
        required: false,
        description: 'Cursor: the id of the last saga of the previous page',
      }),
    },
    resolve: (_root, args, context) =>
      FriendshipUseCase.sagaPage(
        context.userId,
        args.userId,
        { limit: Math.max(1, Math.min(args.limit ?? 30, 100)), after: args.after ?? undefined },
        { state: args.state ?? undefined, favorite: args.favorite ?? undefined },
      ),
  }),
}))
