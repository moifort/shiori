import {
  BookFormatEnum,
  BookLanguageEnum,
  ReadingStatusEnum,
} from '~/domain/book/infrastructure/graphql/enums'
import { SeriesMembershipType } from '~/domain/book/infrastructure/graphql/types'
import type { BookView } from '~/domain/book/types'
import type { Friend } from '~/domain/friendship/types'
import type { FriendProfile, FriendSaga } from '~/domain/friendship/use-case'
import { builder } from '~/domain/shared/graphql/builder'

/** A book on somebody else's shelf.
 *
 *  Its own type rather than `Book`, and deliberately smaller: a friend sees a
 *  shelf, not a diary. There is no field here for the reading note, so no
 *  resolver can ever be added that leaks one, and none for `hidden`, because a
 *  book carrying it never reaches this type at all. */
export const FriendBookType = builder.objectRef<BookView>('FriendBook').implement({
  description:
    'A book as a friend sees it: what is on the shelf and what its owner makes ' +
    'of it, never their reading note.',
  fields: (t) => ({
    id: t.field({ type: 'BookId', resolve: (book) => book.id }),
    title: t.field({ type: 'BookTitle', resolve: (book) => book.title }),
    authors: t.field({ type: ['AuthorName'], resolve: (book) => book.authors }),
    format: t.field({ type: BookFormatEnum, resolve: (book) => book.format }),
    language: t.field({
      type: BookLanguageEnum,
      nullable: true,
      resolve: (book) => book.language ?? null,
    }),
    series: t.field({
      type: SeriesMembershipType,
      nullable: true,
      resolve: (book) => book.series ?? null,
    }),
    coverUrl: t.string({ nullable: true, resolve: (book) => book.coverUrl ?? null }),
    status: t.field({ type: ReadingStatusEnum, resolve: (book) => book.status }),
    rating: t.field({
      type: 'StarRating',
      nullable: true,
      resolve: (book) => book.rating ?? null,
    }),
    favorite: t.boolean({ resolve: (book) => book.favorite ?? false }),
  }),
})

export const FriendSagaType = builder.objectRef<FriendSaga>('FriendSaga').implement({
  description:
    'A saga a friend is reading, as their own books describe it.\n\n' +
    'Taken from the books and nothing else: the shared catalogue is never ' +
    'exposed here, so this says how many volumes they hold and never how many ' +
    'the saga has.',
  fields: (t) => ({
    id: t.exposeString('id', {
      description: 'The saga and the language together: two shelves of one saga are two rows.',
    }),
    name: t.field({ type: 'SeriesName', resolve: (saga) => saga.name }),
    author: t.field({
      type: 'AuthorName',
      nullable: true,
      resolve: (saga) => saga.author ?? null,
    }),
    language: t.field({
      type: BookLanguageEnum,
      nullable: true,
      resolve: (saga) => saga.language ?? null,
    }),
    ownedCount: t.field({
      type: 'Count',
      description: 'How many volumes of the saga are on their shelf.',
      resolve: (saga) => saga.ownedCount,
    }),
  }),
})

export const FriendType = builder.objectRef<Friend>('Friend').implement({
  description: 'Somebody whose library the reader can see, and who can see theirs.',
  fields: (t) => ({
    userId: t.field({ type: 'UserId', resolve: (friend) => friend.userId }),
    firstName: t.string({
      nullable: true,
      description: 'Null for an account that never finished its onboarding.',
      resolve: (friend) => friend.firstName ?? null,
    }),
    since: t.field({ type: 'DateTime', resolve: (friend) => friend.since }),
  }),
})

export const FriendProfileType = builder.objectRef<FriendProfile>('FriendProfile').implement({
  description:
    "One friend's shelf at a glance: what they are reading, what is on their " +
    'pile, what they keep close, and the sagas they are working through.\n\n' +
    'A book marked "do not share" is absent from every list here, and thirty ' +
    'of each is the most any of them carries.',
  fields: (t) => ({
    userId: t.field({ type: 'UserId', resolve: (profile) => profile.userId }),
    firstName: t.string({ nullable: true, resolve: (profile) => profile.firstName ?? null }),
    reading: t.field({
      type: [FriendBookType],
      description: 'Most recently started first.',
      resolve: (profile) => profile.reading,
    }),
    pile: t.field({
      type: [FriendBookType],
      description: 'What they mean to read, most recently added first.',
      resolve: (profile) => profile.pile,
    }),
    favorites: t.field({
      type: [FriendBookType],
      description: 'The books they keep close.',
      resolve: (profile) => profile.favorites,
    }),
    sagas: t.field({
      type: [FriendSagaType],
      resolve: (profile) => profile.sagas,
    }),
  }),
})

export const FriendInvitationType = builder
  .objectRef<{ code: string; expiresAt: Date }>('FriendInvitation')
  .implement({
    description:
      'An invitation to share libraries, for the reader to pass on however they ' +
      'like.\n\n' +
      'One live invitation per reader: asking again answers the same one until ' +
      'it expires, rather than leaving another key to their library outstanding.',
    fields: (t) => ({
      code: t.exposeString('code', {
        description: 'Eight characters, drawn to survive being read aloud.',
      }),
      expiresAt: t.field({ type: 'DateTime', resolve: (invitation) => invitation.expiresAt }),
    }),
  })
