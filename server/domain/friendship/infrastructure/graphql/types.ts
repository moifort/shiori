import type { SharedActivity } from '~/domain/analytics/types'
import { AudibleQuery } from '~/domain/audible/query'
import { listeningProgressOf, shelfDateOf } from '~/domain/book/business-rules'
import {
  BookFormatEnum,
  BookLanguageEnum,
  GenreEnum,
  ReadingStatusEnum,
} from '~/domain/book/infrastructure/graphql/enums'
import { SeriesMembershipType } from '~/domain/book/infrastructure/graphql/types'
import { lastActivityOf } from '~/domain/friendship/business-rules'
import { FriendActivityKindEnum } from '~/domain/friendship/infrastructure/graphql/enums'
import type { Friend } from '~/domain/friendship/types'
import type {
  FriendBook,
  FriendFavorite,
  FriendLibraryPage,
  FriendLoved,
  FriendLover,
  FriendProfile,
  FriendRecommendations,
  FriendSaga,
  FriendSagaPage,
  LovedAuthor,
} from '~/domain/friendship/use-case'
import { SeriesStateEnum } from '~/domain/series/infrastructure/graphql/enums'
import { isAudioSeries } from '~/domain/series/primitives'
import { builder } from '~/domain/shared/graphql/builder'
import { Count, Percentage } from '~/domain/shared/primitives'
import { objectStore } from '~/system/object-store'

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
    shelvedAt: t.field({
      type: 'DateTime',
      description:
        'The day it is shelved on: finished, else started, else added. Their ' +
        "library is ordered and cut into months by it, as the reader's own.",
      resolve: (book) => shelfDateOf(book),
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
    isbn13: t.field({ type: 'Isbn13', nullable: true, resolve: (book) => book.isbn13 ?? null }),
    audibleUrl: t.string({
      nullable: true,
      description:
        "The recording's page on its owner's Audible store, as on the owner's own " +
        'book page. Null on anything but an audiobook imported from Audible.',
      resolve: async (book) =>
        book.audibleAsin
          ? ((await AudibleQuery.recordingUrlOf(book.userId, book.audibleAsin)) ?? null)
          : null,
    }),
    listeningProgress: t.field({
      type: 'Percentage',
      nullable: true,
      description:
        'How far into the recording its owner got, as on their own book page: ' +
        'where the book stands on the shelf, not what they thought of it.',
      resolve: (book) => {
        const progress = listeningProgressOf(book)
        return progress === undefined ? null : Percentage(progress)
      },
    }),
    addedAt: t.field({ type: 'DateTime', resolve: (book) => book.addedAt }),
    startedAt: t.field({
      type: 'DateTime',
      nullable: true,
      description: 'When its owner started it. Null on a book never opened.',
      resolve: (book) => book.startedAt ?? null,
    }),
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
    audio: t.boolean({
      description:
        'The saga heard rather than read: a friend holding it both ways shelves ' +
        'two sagas under one name, and this tells them apart.',
      resolve: (saga) => isAudioSeries(saga.seriesId),
    }),
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
    rating: t.field({
      type: 'StarRating',
      nullable: true,
      description: 'Their stars for the saga as a whole. Null on a saga they did not rate.',
      resolve: (saga) => saga.rating ?? null,
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
        'Carried by a hearted saga and by the sagas of the book in progress ' +
        'touched last, of `lastFinished` and of the last book hearted, empty on ' +
        'any other, and never with ' +
        'a volume its owner keeps to themselves. On `friendSagaPage`, every saga ' +
        'carries them.',
      resolve: (saga) => saga.volumes,
    }),
    shelvedAt: t.field({
      type: 'DateTime',
      description:
        'The latest day one of its volumes was shelved on: what their sagas are ' +
        'ordered and cut into months by.',
      resolve: (saga) => saga.shelvedAt,
    }),
    state: t.field({
      type: SeriesStateEnum,
      description:
        'Where they stand on it, read off the volumes on their shelf alone: none ' +
        'opened, every one read, or in between. Never `UNFOLLOWED`.',
      resolve: (saga) => saga.state,
    }),
  }),
})

export const FriendActivityType = builder.objectRef<SharedActivity>('FriendActivity').implement({
  description:
    "A book that moved lately on a friend's shelf, as the friends list draws it: a " +
    'cover and what happened to it.',
  fields: (t) => ({
    kind: t.field({ type: FriendActivityKindEnum, resolve: (activity) => activity.kind }),
    at: t.field({
      type: 'DateTime',
      description: 'When it happened: the screen decides how far back is still recent.',
      resolve: (activity) => activity.at,
    }),
    bookId: t.field({ type: 'BookId', resolve: (activity) => activity.book.id }),
    title: t.field({ type: 'BookTitle', resolve: (activity) => activity.book.title }),
    format: t.field({ type: BookFormatEnum, resolve: (activity) => activity.book.format }),
    coverUrl: t.string({
      nullable: true,
      description: "Its owner's photo of the cover, else the publisher's.",
      resolve: async ({ book }) =>
        book.coverPath
          ? await objectStore().downloadUrl(book.coverPath)
          : (book.publishedCoverUrl ?? null),
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
    bookCount: t.field({
      type: 'Count',
      description:
        'How many books they share: every one on their shelf, the dropped ones and ' +
        'the ones they keep to themselves aside — what `FriendProfile.bookCount` says.',
      resolve: (friend) => Count(friend.shelf?.bookCount ?? 0),
    }),
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
      deprecationReason: 'Use `recentActivity`, which draws the book in progress as a cover.',
      resolve: (friend) => friend.shelf?.readingTitle ?? null,
    }),
    recentActivity: t.field({
      type: [FriendActivityType],
      description:
        'What moved last on their shelf, one book per kind, always in the same order: ' +
        'in progress, read, hearted, added, dropped. The books they keep to themselves ' +
        'are left out.',
      resolve: (friend) => friend.shelf?.recentActivity ?? [],
    }),
    readThisYear: t.field({
      type: 'Count',
      description:
        'How many books they finished since January 1st, in their own time zone, ' +
        'the ones they keep to themselves left out: what the reading challenge ranks by.',
      resolve: (friend) => Count(friend.shelf?.readThisYear ?? 0),
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
    lastDropped: t.field({
      type: FriendBookType,
      nullable: true,
      description:
        'The book they dropped most recently, by the day its status last moved; ' +
        'its `lastActivityAt` says when. Null when they dropped none.',
      resolve: (profile) => profile.lastDropped ?? null,
    }),
    lastAdded: t.field({
      type: FriendBookType,
      nullable: true,
      description:
        'The book they shelved most recently, whatever its status since; its ' +
        '`addedAt` says when. Null on an empty shelf.',
      resolve: (profile) => profile.lastAdded ?? null,
    }),
    bookCount: t.field({
      type: 'Count',
      description:
        'How many books their library shows: every one they share, the dropped ' +
        'ones aside — what `friendLibraryPage` lists unfiltered.',
      resolve: (profile) => profile.bookCount,
    }),
    readThisYear: t.field({
      type: 'Count',
      description:
        'How many books they finished since January 1st, in their own time zone, ' +
        'the ones they keep to themselves left out — the figure `Friend` carries.',
      resolve: (profile) => profile.readThisYear,
    }),
  }),
})

export const FriendLibraryPageType = builder
  .objectRef<FriendLibraryPage>('FriendLibraryPage')
  .implement({
    description:
      "One page of a friend's library. The id of its last book is the cursor for the next.",
    fields: (t) => ({
      books: t.field({
        type: [FriendBookType],
        description: 'Newest first on `shelvedAt`, as the Library tab draws them.',
        resolve: (page) => page.books,
      }),
      hasMore: t.exposeBoolean('hasMore', { description: 'Whether more books follow this page' }),
    }),
  })

export const FriendSagaPageType = builder.objectRef<FriendSagaPage>('FriendSagaPage').implement({
  description: "One page of a friend's sagas. The id of its last saga is the cursor for the next.",
  fields: (t) => ({
    sagas: t.field({
      type: [FriendSagaType],
      description: 'The saga shelved last first, each with every volume on the shelf.',
      resolve: (page) => page.sagas,
    }),
    hasMore: t.exposeBoolean('hasMore', { description: 'Whether more sagas follow this page' }),
  }),
})

export const FriendFavoriteType = builder.objectRef<FriendFavorite>('FriendFavorite').implement({
  description:
    'A heart one friend gave lately: to a saga, or to a book no hearted saga of theirs ' +
    'already stands for. Exactly one of `book` and `saga` is set.',
  fields: (t) => ({
    friendId: t.field({ type: 'UserId', resolve: (favorite) => favorite.friendId }),
    friendName: t.string({
      nullable: true,
      description: 'Null for an account that never finished its onboarding.',
      resolve: (favorite) => favorite.friendName ?? null,
    }),
    favoritedAt: t.field({ type: 'DateTime', resolve: (favorite) => favorite.favoritedAt }),
    book: t.field({
      type: FriendBookType,
      nullable: true,
      resolve: (favorite) => favorite.book ?? null,
    }),
    saga: t.field({
      type: FriendSagaType,
      nullable: true,
      description: 'Carries its first volume only, as the cover its tile draws.',
      resolve: (favorite) => favorite.saga ?? null,
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

export const FriendLoverType = builder.objectRef<FriendLover>('FriendLover').implement({
  description: 'A friend who loves something Découvrir suggests.',
  fields: (t) => ({
    userId: t.field({ type: 'UserId', resolve: (lover) => lover.userId }),
    firstName: t.string({
      nullable: true,
      description: 'Null for an account that never finished its onboarding.',
      resolve: (lover) => lover.firstName ?? null,
    }),
  }),
})

const FRIENDS_DESCRIPTION =
  'Every friend who hearted it, the newest heart first: the first is the one whose ' +
  'copy stands for it.'
const LOVED_AT_DESCRIPTION =
  'The newest heart it was given — or, for a heart given before its date was kept, ' +
  'the last activity on what was hearted: what the suggestions are ordered on.'
const LOVED_BY_MANY_DESCRIPTION =
  'Hearted by a third of the reader’s friends and by two of them at least: what ' +
  'Découvrir flames.'

export const FriendLovedBookType = builder
  .objectRef<FriendLoved<FriendBook>>('FriendLovedBook')
  .implement({
    description:
      'A book the reader’s friends hearted and the reader holds in no format, as ' +
      'Découvrir suggests it.',
    fields: (t) => ({
      book: t.field({
        type: FriendBookType,
        description: 'The copy of the friend who hearted it last, for its page to open on.',
        resolve: (loved) => loved.item,
      }),
      friends: t.field({
        type: [FriendLoverType],
        description: FRIENDS_DESCRIPTION,
        resolve: (loved) => loved.friends,
      }),
      lovedAt: t.field({
        type: 'DateTime',
        description: LOVED_AT_DESCRIPTION,
        resolve: (loved) => loved.lovedAt,
      }),
      lovedByMany: t.boolean({
        description: LOVED_BY_MANY_DESCRIPTION,
        resolve: (loved) => loved.lovedByMany,
      }),
    }),
  })

export const FriendLovedSagaType = builder
  .objectRef<FriendLoved<FriendSaga>>('FriendLovedSaga')
  .implement({
    description:
      'A saga the reader’s friends hearted, read or heard, and the reader holds no ' +
      'volume of in either format, as Découvrir suggests it.',
    fields: (t) => ({
      saga: t.field({
        type: FriendSagaType,
        description:
          'The saga of the friend who hearted it last. Carries its first volume only, ' +
          'as the cover its tile draws; `ownedCount` is how many volumes that friend holds.',
        resolve: (loved) => loved.item,
      }),
      friends: t.field({
        type: [FriendLoverType],
        description: FRIENDS_DESCRIPTION,
        resolve: (loved) => loved.friends,
      }),
      lovedAt: t.field({
        type: 'DateTime',
        description: LOVED_AT_DESCRIPTION,
        resolve: (loved) => loved.lovedAt,
      }),
      lovedByMany: t.boolean({
        description: LOVED_BY_MANY_DESCRIPTION,
        resolve: (loved) => loved.lovedByMany,
      }),
    }),
  })

export const LovedAuthorType = builder.objectRef<LovedAuthor>('LovedAuthor').implement({
  description: 'An author as the friends’ hearts name them.',
  fields: (t) => ({
    key: t.field({
      type: 'AuthorKey',
      description: 'What their page is opened on.',
      resolve: (author) => author.key,
    }),
    name: t.field({
      type: 'AuthorName',
      description: 'The spelling of the book hearted last.',
      resolve: (author) => author.name,
    }),
    portraitUrl: t.field({
      type: 'PortraitUrl',
      nullable: true,
      description:
        'Their photograph, once somebody has opened their page and Wikipedia had ' +
        'one. Null until then: the app draws their initials.',
      resolve: (author) => author.portraitUrl ?? null,
    }),
  }),
})

export const FriendLovedAuthorType = builder
  .objectRef<FriendLoved<LovedAuthor>>('FriendLovedAuthor')
  .implement({
    description:
      'An author of a book or a saga the reader’s friends hearted, whom the reader ' +
      'holds no book of, as Découvrir suggests them.',
    fields: (t) => ({
      author: t.field({ type: LovedAuthorType, resolve: (loved) => loved.item }),
      friends: t.field({
        type: [FriendLoverType],
        description: FRIENDS_DESCRIPTION,
        resolve: (loved) => loved.friends,
      }),
      lovedAt: t.field({
        type: 'DateTime',
        description: LOVED_AT_DESCRIPTION,
        resolve: (loved) => loved.lovedAt,
      }),
      lovedByMany: t.boolean({
        description: LOVED_BY_MANY_DESCRIPTION,
        resolve: (loved) => loved.lovedByMany,
      }),
    }),
  })

export const FriendRecommendationsType = builder
  .objectRef<FriendRecommendations>('FriendRecommendations')
  .implement({
    description:
      'What the reader’s friends love and the reader does not hold, whatever the ' +
      'format: the Découvrir shelves’ “Coups de cœur de vos amis”. Twenty of each at ' +
      'most, the newest heart first.',
    fields: (t) => ({
      books: t.field({ type: [FriendLovedBookType], resolve: (found) => found.books }),
      sagas: t.field({ type: [FriendLovedSagaType], resolve: (found) => found.sagas }),
      authors: t.field({ type: [FriendLovedAuthorType], resolve: (found) => found.authors }),
    }),
  })
