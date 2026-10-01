import { EditionOfferType } from '~/domain/awaited-edition/infrastructure/graphql/types'
import { BookLanguageEnum, ReadingStatusEnum } from '~/domain/book/infrastructure/graphql/enums'
import { AudioAvailabilityEnum } from '~/domain/friendship/infrastructure/graphql/enums'
import {
  FriendBookType,
  FriendFavoriteType,
  FriendLibraryPageType,
  FriendProfileType,
  FriendRecommendationsType,
  FriendSagaPageType,
  FriendSagaType,
  FriendType,
} from '~/domain/friendship/infrastructure/graphql/types'
import { FriendshipUseCase } from '~/domain/friendship/use-case'
import { SeriesStateEnum } from '~/domain/series/infrastructure/graphql/enums'
import { builder } from '~/domain/shared/graphql/builder'
import { languageOf } from '~/domain/shared/language'

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

  friendFavorites: t.field({
    type: [FriendFavoriteType],
    description:
      "Each friend's last heart of the last thirty days, a saga or a book, the newest " +
      'first, twelve at most: the news the dashboard shows from the people the reader ' +
      'shares with.\n\n' +
      'Only a dated heart counts. A book marked "do not share" is never among them.',
    resolve: (_root, _args, context) => FriendshipUseCase.recentFavorites(context.userId),
  }),

  friendRecommendations: t.field({
    type: FriendRecommendationsType,
    description:
      'What the reader’s friends hearted and the reader does not hold, for Découvrir: ' +
      'books, sagas and the authors of both, the newest heart first, twenty of each at ' +
      'most. Held is judged on the story, whatever the format — a friend’s recording ' +
      'is a story the reader may take on paper.\n\n' +
      'A book marked "do not share" is never among them.',
    resolve: (_root, _args, context) => FriendshipUseCase.recommendations(context.userId),
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

  friendBookAudio: t.field({
    type: AudioAvailabilityEnum,
    nullable: true,
    description:
      "Whether the reader may take one book of a friend's shelf as an audiobook: a " +
      'recording is, a printed book is when Audible sells it in its language under the ' +
      'same title and author. Asks Audible, so a page asks it only when it opens.\n\n' +
      'Null for a stranger, a book that does not exist and a book marked "do not ' +
      'share" alike.',
    args: {
      userId: t.arg({ type: 'UserId', required: true, description: 'The friend' }),
      bookId: t.arg({ type: 'BookId', required: true }),
    },
    resolve: (_root, args, context) =>
      FriendshipUseCase.audio(context.userId, args.userId, args.bookId),
  }),

  friendBookEditionOffer: t.field({
    type: EditionOfferType,
    nullable: true,
    description:
      "What the page of a friend's book offers to await in the app's language: its " +
      'translation or its recording — and, for a printed book already in that ' +
      'language, its recording once Audible is known not to sell it. Asks Audible for ' +
      'that last case, so a page asks it only when it opens.\n\n' +
      'Null for a stranger, a book that does not exist and a book marked "do not ' +
      'share" alike.',
    args: {
      userId: t.arg({ type: 'UserId', required: true, description: 'The friend' }),
      bookId: t.arg({ type: 'BookId', required: true }),
    },
    resolve: (_root, args, context) =>
      FriendshipUseCase.editionOffer(
        context.userId,
        args.userId,
        args.bookId,
        languageOf(context.event),
      ),
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
        deprecationReason: 'Use `loved`, which follows the hearts with the stars.',
      }),
      loved: t.arg.boolean({
        required: false,
        description:
          'The favourites view: the sagas they hearted or rated, hearts first, then ' +
          'five stars down to one, each rank shelved last first.',
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
        {
          state: args.state ?? undefined,
          favorite: args.favorite ?? undefined,
          loved: args.loved ?? undefined,
        },
      ),
  }),

  friendSaga: t.field({
    type: FriendSagaType,
    nullable: true,
    description:
      "One saga of a friend's shelf — or of the reader's own, previewed — with every " +
      'volume of it they share, in reading order: what the saga screen draws against ' +
      'its catalogue when opened from their shelf, so where it stands is theirs, not ' +
      "the reader's.\n\n" +
      'Null for a stranger and for a saga they share no volume of alike. A book marked ' +
      '"do not share" is never among the volumes.',
    args: {
      userId: t.arg({ type: 'UserId', required: true, description: 'The friend' }),
      seriesId: t.arg({ type: 'SeriesId', required: true }),
      language: t.arg({
        type: BookLanguageEnum,
        required: false,
        description:
          'The edition opened, for a saga they hold in more than one language. Absent, ' +
          'the first edition by name answers.',
      }),
    },
    resolve: (_root, args, context) =>
      FriendshipUseCase.saga(
        context.userId,
        args.userId,
        args.seriesId,
        args.language ?? undefined,
      ),
  }),
}))
