import {
  BookFormatEnum,
  BookLanguageEnum,
  GenreEnum,
  ReadingStatusEnum,
} from '~/domain/book/infrastructure/graphql/enums'
import { SeriesMembershipType } from '~/domain/book/infrastructure/graphql/types'
import { lastActivityOf } from '~/domain/friendship/business-rules'
import type { Friend } from '~/domain/friendship/types'
import type { FriendBook, FriendProfile, FriendSaga } from '~/domain/friendship/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { Count } from '~/domain/shared/primitives'

/** A book on somebody else's shelf.
 *
 *  Its own type rather than `Book`, and deliberately smaller: a friend sees a
 *  shelf, not a diary. There is no field here for the reading note, so no
 *  resolver can ever be added that leaks one, and none for `hidden`, because a
 *  book carrying it never reaches this type at all. */
export const FriendBookType = builder.objectRef<FriendBook>('FriendBook').implement({
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
    favoritedAt: t.field({
      type: 'DateTime',
      nullable: true,
      description:
        'When its owner hearted it: what is new among their favourites. Null ' +
        'on a book not hearted, and on a heart given before the date was kept.',
      resolve: (book) => book.favoritedAt ?? null,
    }),
    lastActivityAt: t.field({
      type: 'DateTime',
      description:
        'When its owner last did anything with it — picked it up, moved its ' +
        'status, or had a listening sync move its position: what is recent on the shelf.',
      resolve: (book) => lastActivityOf(book),
    }),
    finishedAt: t.field({
      type: 'DateTime',
      nullable: true,
      description: 'When its owner finished it. Null on a book not read, or read with no date.',
      resolve: (book) => book.finishedAt ?? null,
    }),
    inLibrary: t.boolean({
      description:
        'The reader already owns this story — same title and first author, ' +
        'whatever the edition — so there is nothing to add.',
      resolve: (book) => book.inLibrary,
    }),
    publisher: t.field({
      type: 'Publisher',
      nullable: true,
      resolve: (book) => book.publisher ?? null,
    }),
    firstPublishedIn: t.field({
      type: 'Year',
      nullable: true,
      resolve: (book) => book.firstPublishedIn ?? null,
    }),
    synopsis: t.field({
      type: 'Synopsis',
      nullable: true,
      resolve: (book) => book.synopsis ?? null,
    }),
    genre: t.field({ type: GenreEnum, nullable: true, resolve: (book) => book.genre ?? null }),
    subgenres: t.field({
      type: ['Subgenre'],
      resolve: (book) => book.subgenres.map(({ label }) => label),
    }),
    pageCount: t.field({
      type: 'PageCount',
      nullable: true,
      resolve: (book) => book.pageCount ?? null,
    }),
    durationMinutes: t.int({ nullable: true, resolve: (book) => book.durationMinutes ?? null }),
    narrators: t.field({ type: ['NarratorName'], resolve: (book) => book.narrators ?? [] }),
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
    seriesId: t.field({
      type: 'SeriesId',
      description: 'The saga alone, whatever the language: what its page is opened on.',
      resolve: (saga) => saga.seriesId,
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
    favorite: t.boolean({
      description:
        'Hearted by its owner. Its hearted volumes are then left out of the ' +
        'favourite books, which the saga already stands for.',
      resolve: (saga) => saga.favorite,
    }),
    favoritedAt: t.field({
      type: 'DateTime',
      nullable: true,
      description:
        'When its owner hearted it. Null on a saga not hearted, and on a heart ' +
        'given before the date was kept.',
      resolve: (saga) => saga.favoritedAt ?? null,
    }),
    genre: t.field({
      type: GenreEnum,
      nullable: true,
      description: 'The genre most of the volumes on their shelf carry.',
      resolve: (saga) => saga.genre ?? null,
    }),
    subgenre: t.field({
      type: 'Subgenre',
      nullable: true,
      description: 'The leading subgenre of a volume of that genre.',
      resolve: (saga) => saga.subgenre?.label ?? null,
    }),
    volumes: t.field({
      type: [FriendBookType],
      description:
        'Its volumes on the shelf, in reading order, for a strip of covers. ' +
        'Only a hearted saga carries them — the favourites are where a saga is ' +
        'drawn that way — and never a volume its owner keeps to themselves.',
      resolve: (saga) => saga.volumes,
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
    favoriteCount: t.field({
      type: 'Count',
      description: 'How many books they hearted, the ones they keep to themselves left out.',
      resolve: (friend) => Count(friend.shelf?.favoriteCount ?? 0),
    }),
    readingCount: t.field({
      type: 'Count',
      description: 'How many books they are reading.',
      resolve: (friend) => Count(friend.shelf?.readingCount ?? 0),
    }),
    toReadCount: t.field({
      type: 'Count',
      description: 'How many books wait on their pile.',
      resolve: (friend) => Count(friend.shelf?.toReadCount ?? 0),
    }),
    readingTitle: t.field({
      type: 'BookTitle',
      nullable: true,
      description: 'The book they started most recently, null when they are reading nothing.',
      resolve: (friend) => friend.shelf?.readingTitle ?? null,
    }),
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
      description: 'Most recently active first: started, moved, or advanced by a listening sync.',
      resolve: (profile) => profile.reading,
    }),
    pile: t.field({
      type: [FriendBookType],
      description: 'What they mean to read, most recently added first.',
      resolve: (profile) => profile.pile,
    }),
    favorites: t.field({
      type: [FriendBookType],
      description:
        'The books they keep close, most recently hearted first, less the ' +
        'volumes of a saga they hearted: that saga, among `sagas`, stands for them.',
      resolve: (profile) => profile.favorites,
    }),
    sagas: t.field({
      type: [FriendSagaType],
      resolve: (profile) => profile.sagas,
    }),
    lastFinished: t.field({
      type: FriendBookType,
      nullable: true,
      description:
        'The book they finished most recently, null when no book read carries ' +
        'its finishing date.',
      resolve: (profile) => profile.lastFinished ?? null,
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
