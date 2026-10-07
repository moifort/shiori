import { AnalyticsUseCase } from '~/domain/analytics/use-case'
import { AuthorQuery } from '~/domain/author/query'
import type { AuthorKey, PortraitUrl } from '~/domain/author/types'
import type { EditionOffer } from '~/domain/awaited-edition/types'
import { AwaitedEditionUseCase, type AwaitOutcome } from '~/domain/awaited-edition/use-case'
import {
  seriesRatingsOf,
  shelfDateOf,
  shelfKeyOf,
  shelfKeysOf,
  shelfPageOf,
  shelvedOf,
} from '~/domain/book/business-rules'
import { BookQuery } from '~/domain/book/query'
import type {
  Book,
  BookFormat,
  BookId,
  BookLanguage,
  BookMedium,
  BookView,
  Genre,
  ReadingStatus,
  StarRating,
  TaggedSubgenre,
} from '~/domain/book/types'
import { READING_STATUSES } from '~/domain/book/types'
import { BookUseCase } from '~/domain/book/use-case'
import type { ReleaseFormat } from '~/domain/discovery/types'
import { DiscoveryUseCase } from '~/domain/discovery/use-case'
import {
  type FriendPick,
  favoritesOutsideSagas,
  friendPicksOf,
  friendSagaStateOf,
  inReadingOrder,
  lastActivityOf,
  lastAddedOf,
  lastDroppedOf,
  lastFinishedOf,
  newestFavoritesFirst,
  recentHeartsOf,
  subgenreOf,
} from '~/domain/friendship/business-rules'
import { FriendshipQuery } from '~/domain/friendship/query'
import type { Friend } from '~/domain/friendship/types'
import { type FollowedSaga, followedSagasOf, genreOf } from '~/domain/series/business-rules'
import type { SeriesId, SeriesName, SeriesState } from '~/domain/series/types'
import { SeriesOpinionQuery } from '~/domain/series-opinion/query'
import type { Language } from '~/domain/shared/language'
import { Count, PersonName } from '~/domain/shared/primitives'
import { lovedFirst, lovedRankOf } from '~/domain/shared/rating'
import type { AuthorName, Count as CountValue, UserId } from '~/domain/shared/types'
import { UserQuery } from '~/domain/user/query'

/** How many of a shelf a profile shows. A friend's profile is a glance at what
 *  they are reading, not a second library to browse: a pile of four hundred
 *  would take a page of its own, and the point of the screen is the handful at
 *  the top of it. */
const SHELF_SHOWN = 30

/** One saga a friend is reading, as their own books describe it.
 *
 *  Taken from the books and nothing else. The catalogue is never exposed here:
 *  it is a shared document about the world, and what a friend is entitled to see
 *  is what somebody chose to put on their shelf. So this says "four volumes of
 *  Dune", never "four of fourteen". */
export type FriendSaga = {
  id: string
  /** The saga alone, for the reader's own shelf to open it on its page. */
  seriesId: SeriesId
  name: SeriesName
  author?: AuthorName
  language?: BookLanguage
  ownedCount: CountValue
  /** Hearted by its owner. A hearted saga stands for its volumes among the
   *  favourites, which then do not list them again one by one. */
  favorite: boolean
  /** When its owner hearted it. Absent on a saga not hearted, and on a heart
   *  given before the date was kept. */
  favoritedAt?: Date
  /** Its owner's stars for the saga as a whole. Absent on a saga not rated. */
  rating?: StarRating
  genre?: Genre
  subgenre?: TaggedSubgenre
  /** Its volumes on the shelf, in reading order, for a strip of covers.
   *  Carried by a hearted saga and by the sagas of the book in progress
   *  touched last, of the last book finished and of the last book hearted —
   *  the recent activity draws those — and empty on any other: each cover is
   *  a signed URL. On a
   *  page of their sagas, every saga carries them. */
  volumes: FriendBook[]
  /** The latest day one of its volumes was shelved on: what their sagas are
   *  ordered and cut into months by, as the reader's own Series tab. */
  shelvedAt: Date
  /** Where they stand on it, read off their own volumes. */
  state: Exclude<SeriesState, 'unfollowed'>
}

/** A book on a friend's shelf, with whether the reader already owns the
 *  story — the "Chez vous" badge, matched on the shelf key the imports use. */
export type FriendBook = BookView & { inLibrary: boolean }

/** A friend's shelf, as the profile screen draws it — and the reader's own,
 *  drawn the same way, so what they are shown of it is what their friends see. */
export type FriendProfile = {
  userId: UserId
  firstName?: string
  reading: FriendBook[]
  pile: FriendBook[]
  /** The hearted books a hearted saga does not already stand for. */
  favorites: FriendBook[]
  sagas: FriendSaga[]
  /** The book they finished most recently, when one carries its date. */
  lastFinished?: FriendBook
  /** The book they dropped most recently. */
  lastDropped?: FriendBook
  /** The book they shelved most recently. */
  lastAdded?: FriendBook
  /** How many books their library shows — every one they share, the
   *  dropped ones aside, as the reader's own Library tab. */
  bookCount: CountValue
  /** How many books they finished since January 1st, as the friends list
   *  counts them. */
  readThisYear: CountValue
}

/** A heart one friend gave lately, as the dashboard shows it: a saga or a
 *  book, whose, and when. */
export type FriendFavorite = {
  friendId: UserId
  friendName?: string
  favoritedAt: Date
  book?: FriendBook
  /** Carries its first volume only, as the cover its tile draws. */
  saga?: FriendSaga
}

/** How far back a friend's heart is still news on the dashboard: the window
 *  the recent activity of a profile keeps. */
const FAVORITES_RECENT_MS = 30 * 24 * 60 * 60 * 1000

/** How many of them the dashboard shows. */
const FAVORITES_SHOWN = 12

/** A friend who loves something, by first name. */
export type FriendLover = { userId: UserId; firstName?: string }

/** Something the reader's friends love, as Découvrir shows it: who loves it,
 *  the newest heart first, and whether enough of them do to flame it. */
export type FriendLoved<Item> = Omit<FriendPick<Item>, 'friendIds'> & { friends: FriendLover[] }

/** An author the friends' hearts name, with their face when the author
 *  catalogue has one. */
export type LovedAuthor = { key: AuthorKey; name: AuthorName; portraitUrl?: PortraitUrl }

/** What the reader's friends love and the reader does not hold: the books,
 *  the sagas — each carrying its first volume, as the cover its tile draws —
 *  and the authors. */
export type FriendRecommendations = {
  books: FriendLoved<FriendBook>[]
  sagas: FriendLoved<FriendSaga>[]
  authors: FriendLoved<LovedAuthor>[]
}

/** Whether a friend's book can be taken as an audiobook: Audible sells it in
 *  its language, sells none, or could not be asked — in which case the reader
 *  is left to decide, as before anybody asked. */
export type AudioAvailability = 'available' | 'unavailable' | 'unknown'

/** How many of each Découvrir shows. */
const RECOMMENDATIONS_SHOWN = 20

/** One page of a friend's library or of their sagas, and whether more follow. */
export type FriendLibraryPage = { books: FriendBook[]; hasMore: boolean }
export type FriendSagaPage = { sagas: FriendSaga[]; hasMore: boolean }

/** The statuses a library shows unfiltered: all but the dropped books, which
 *  have their own filter — the reader's own Library tab does the same. */
const SHELVED_STATUSES: readonly ReadingStatus[] = READING_STATUSES.filter(
  (status) => status !== 'dropped',
)

/** The statuses a book copied from a friend may land in: on the pile, or
 *  straight among the books read, for a reader who had already read it. */
export type CopiedStatus = Extract<ReadingStatus, 'to-read' | 'read'>

export namespace FriendshipUseCase {
  /** The reader's friends, named. One scan of the friendships and one batched
   *  read of the profiles behind them — never a read per row. */
  export const friends = async (userId: UserId): Promise<Friend[]> => {
    const friendships = await FriendshipQuery.all(userId)
    const others = friendships.map((friendship) => ({
      friendship,
      userId: friendship.userIds.find((member) => member !== userId),
    }))
    const ids = others.flatMap((entry) => (entry.userId ? [entry.userId] : []))
    const [names, shelves] = await Promise.all([
      UserQuery.namesOf(ids),
      AnalyticsUseCase.sharedShelves(ids),
    ])
    return others
      .flatMap((entry) =>
        entry.userId
          ? [
              {
                userId: entry.userId,
                firstName: names.get(entry.userId),
                since: entry.friendship.since,
                shelf: shelves.get(entry.userId),
              },
            ]
          : [],
      )
      .sort((left, right) => (left.firstName ?? '').localeCompare(right.firstName ?? ''))
  }

  /** What one friend is reading.
   *
   *  Answers `'not-friends'` for anybody the reader is not friends with, which
   *  is also the answer for an id that names nobody: a stranger must not be able
   *  to tell an account that refused them from one that does not exist.
   *
   *  A book marked "do not share" is absent from every one of these lists, and
   *  so is the reading note on every book that is here — a friend sees a shelf,
   *  not a diary. */
  export const profile = async (
    userId: UserId,
    friendId: UserId,
  ): Promise<FriendProfile | 'not-friends'> => {
    if (!(await FriendshipQuery.areFriends(userId, friendId))) return 'not-friends'
    const [owned, shelf] = await Promise.all([
      BookQuery.shelfKeys(userId),
      sharedShelfOf(friendId, SHELF_SHOWN),
    ])
    return marked(shelf, (book) => ownsStory(owned, book))
  }

  /** The reader's own shelf exactly as a friend sees it: the books marked "do
   *  not share" left out, a hearted saga standing for its volumes. Uncut, since
   *  it is the reader's to read through and to send on in full. */
  export const ownShelf = async (userId: UserId): Promise<FriendProfile> =>
    marked(await sharedShelfOf(userId), () => true)

  /** One book of a friend's shelf, for the read-only page a row opens. Null
   *  for a stranger's book, a book that does not exist and a book marked "do
   *  not share" alike. The reader's own shelf opens the same page, previewing
   *  what their friends are shown. */
  export const book = async (
    userId: UserId,
    friendId: UserId,
    bookId: BookId,
  ): Promise<FriendBook | null> => {
    if (!(await canRead(userId, friendId))) return null
    const [book, owned] = await Promise.all([
      BookQuery.sharedById(friendId, bookId),
      BookQuery.shelfKeys(userId),
    ])
    return book ? { ...book, inLibrary: ownsStory(owned, book) } : null
  }

  /** One page of a friend's library — or of the reader's own, previewed —
   *  as their own Library tab draws it: newest first on the day each book was
   *  shelved, the dropped books left out unless asked for, the ones marked "do
   *  not share" never. Null for a stranger. */
  export const libraryPage = async (
    viewerId: UserId,
    ownerId: UserId,
    page: { limit: number; after?: BookId },
    view: { status?: ReadingStatus; favorite?: boolean },
  ): Promise<FriendLibraryPage | null> => {
    if (!(await canRead(viewerId, ownerId))) return null
    const [books, owned] = await Promise.all([
      BookQuery.shared(ownerId),
      BookQuery.shelfKeys(viewerId),
    ])
    const statuses = view.status ? [view.status] : view.favorite ? undefined : SHELVED_STATUSES
    const kept = books.filter(
      (book) =>
        (!view.favorite || book.favorite === true) && (!statuses || statuses.includes(book.status)),
    )
    const { books: shown, hasMore } = shelfPageOf(shelvedOf(kept), page.limit, page.after)
    const signed = await BookQuery.withSignedCovers(shown)
    return {
      books: signed.map((book) => ({ ...book, inLibrary: ownsStory(owned, book) })),
      hasMore,
    }
  }

  /** One page of a friend's sagas — or of the reader's own, previewed — as
   *  their own Series tab draws them: the saga shelved last first, each with
   *  every volume on the shelf as a cover — or, `loved`, the sagas they
   *  hearted or rated, hearts first and then five stars down to one. `after`
   *  is the id of the last saga of the previous page. Null for a stranger. */
  export const sagaPage = async (
    viewerId: UserId,
    ownerId: UserId,
    page: { limit: number; after?: string },
    view: { state?: SeriesState; favorite?: boolean; loved?: boolean } = {},
  ): Promise<FriendSagaPage | null> => {
    if (!(await canRead(viewerId, ownerId))) return null
    const [books, favoriteSagas, ratings, owned] = await Promise.all([
      BookQuery.shared(ownerId),
      favoriteSagasOf(ownerId),
      sagaRatingsOf(ownerId),
      BookQuery.shelfKeys(viewerId),
    ])
    const newestFirst = (left: FollowedSaga<Book>, right: FollowedSaga<Book>) =>
      sagaShelvedAt(right).getTime() - sagaShelvedAt(left).getTime() ||
      left.name.localeCompare(right.name)
    const kept = followedSagasOf(books).filter(
      (saga) =>
        (!view.state || friendSagaStateOf(saga.books) === view.state) &&
        (!view.favorite || favoriteSagas.has(saga.id)),
    )
    const sagas = (
      view.loved
        ? lovedFirst(
            kept,
            (saga) =>
              lovedRankOf({ favorite: favoriteSagas.has(saga.id), rating: ratings.get(saga.id) }),
            newestFirst,
          )
        : kept.sort(newestFirst)
    ).map((saga) => ({ saga, id: `${saga.id}\u0000${saga.language ?? ''}` }))
    const start = page.after ? sagas.findIndex(({ id }) => id === page.after) + 1 : 0
    const shown = sagas.slice(start, start + page.limit)
    const volumes = await Promise.all(
      shown.map(({ saga }) => BookQuery.withSignedCovers(inReadingOrder(saga.books))),
    )
    return {
      sagas: shown.map(({ saga }, index) =>
        friendSagaOf(
          saga,
          favoriteSagas,
          ratings,
          (volumes[index] ?? []).map((book) => ({ ...book, inLibrary: ownsStory(owned, book) })),
        ),
      ),
      hasMore: start + page.limit < sagas.length,
    }
  }

  /** One saga of a friend's shelf — or of the reader's own, previewed — with
   *  every volume of it they share, in reading order: what the saga screen
   *  draws against its catalogue when opened from their shelf, so the ring
   *  and the volumes read as theirs. Only the edition named, when one is.
   *  Null for a stranger, and for a saga they share no volume of. Whether the
   *  viewer owns each story is judged on their own volumes of the saga, not
   *  their whole library: the screen does not draw it. */
  export const saga = async (
    viewerId: UserId,
    ownerId: UserId,
    seriesId: SeriesId,
    edition?: BookLanguage,
  ): Promise<FriendSaga | null> => {
    if (!(await canRead(viewerId, ownerId))) return null
    const [held, opinion, viewerVolumes] = await Promise.all([
      BookQuery.sharedInSaga(ownerId, seriesId),
      SeriesOpinionQuery.of(ownerId, seriesId),
      BookQuery.bySeries(viewerId, seriesId),
    ])
    const [saga] = followedSagasOf(
      edition ? held.filter((book) => book.language === edition) : held,
    )
    if (!saga) return null
    const owned = shelfKeysOf(viewerVolumes)
    const favorites = new Map<SeriesId, Date | undefined>(
      opinion?.favorite ? [[seriesId, opinion.favoritedAt]] : [],
    )
    const ratings = seriesRatingsOf(opinion ? [opinion] : [])
    const volumes = await BookQuery.withSignedCovers(inReadingOrder(saga.books))
    return friendSagaOf(
      saga,
      favorites,
      ratings,
      volumes.map((book) => ({ ...book, inLibrary: ownsStory(owned, book) })),
    )
  }

  /** Each friend's last heart of the last thirty days, a saga or a book,
   *  the newest first: the news from the people the reader shares with. One
   *  scan of each friend's shelf and hearts; only the covers drawn are signed,
   *  a saga's first volume standing for it. A book marked "do not share" is
   *  never among them. */
  export const recentFavorites = async (
    userId: UserId,
    now = new Date(),
  ): Promise<FriendFavorite[]> => {
    const friendIds = await FriendshipQuery.friendsOf(userId)
    if (friendIds.length === 0) return []
    const [names, owned, shelves] = await Promise.all([
      UserQuery.namesOf(friendIds),
      BookQuery.shelfKeys(userId),
      Promise.all(
        friendIds.map(async (friendId) => {
          const [books, favoriteSagas, ratings] = await Promise.all([
            BookQuery.shared(friendId),
            favoriteSagasOf(friendId),
            sagaRatingsOf(friendId),
          ])
          return { friendId, books, sagas: followedSagasOf(books), favoriteSagas, ratings }
        }),
      ),
    ])
    const hearts = recentHeartsOf(
      shelves,
      new Date(now.getTime() - FAVORITES_RECENT_MS),
      FAVORITES_SHOWN,
    )
    const favoriteSagas = new Map(shelves.map((shelf) => [shelf.friendId, shelf.favoriteSagas]))
    const ratings = new Map(shelves.map((shelf) => [shelf.friendId, shelf.ratings]))
    const mark = (book: BookView): FriendBook => ({ ...book, inLibrary: ownsStory(owned, book) })
    return Promise.all(
      hearts.map(async ({ friendId, favoritedAt, book, saga }): Promise<FriendFavorite> => {
        const whose = { friendId, friendName: names.get(friendId), favoritedAt }
        if (book) {
          const [signed] = await BookQuery.withSignedCovers([book])
          return { ...whose, ...(signed ? { book: mark(signed) } : {}) }
        }
        const first = inReadingOrder(saga.books).slice(0, 1)
        const volumes = (await BookQuery.withSignedCovers(first)).map(mark)
        return {
          ...whose,
          saga: friendSagaOf(
            saga,
            favoriteSagas.get(friendId) ?? new Map(),
            ratings.get(friendId) ?? new Map(),
            volumes,
          ),
        }
      }),
    )
  }

  /** What the reader's friends love that the reader does not hold, for
   *  Découvrir: the books and sagas they hearted and the authors of both, the
   *  newest heart first. Held is judged on the story, whatever the format. One
   *  scan of the reader's library and of each friend's shelf and hearts; only
   *  the covers drawn are signed, and the faces are one batched read of the
   *  author catalogue. A book marked "do not share" is never among them. */
  export const recommendations = async (userId: UserId): Promise<FriendRecommendations> => {
    const friendIds = await FriendshipQuery.friendsOf(userId)
    if (friendIds.length === 0) return { books: [], sagas: [], authors: [] }
    const [names, held, shelves] = await Promise.all([
      UserQuery.namesOf(friendIds),
      BookQuery.all(userId),
      Promise.all(
        friendIds.map(async (friendId) => {
          const [books, favoriteSagas, ratings] = await Promise.all([
            BookQuery.shared(friendId),
            favoriteSagasOf(friendId),
            sagaRatingsOf(friendId),
          ])
          return { friendId, books, sagas: followedSagasOf(books), favoriteSagas, ratings }
        }),
      ),
    ])
    const picks = friendPicksOf(shelves, held, RECOMMENDATIONS_SHOWN)
    const byFriend = new Map(shelves.map((shelf) => [shelf.friendId, shelf]))
    const loved = <Item, Shown>(pick: FriendPick<Item>, item: Shown): FriendLoved<Shown> => {
      const { friendIds, ...rest } = pick
      return {
        ...rest,
        item,
        friends: friendIds.map((id) => ({ userId: id, firstName: names.get(id) })),
      }
    }
    const unowned = (books: BookView[]): FriendBook[] =>
      books.map((book) => ({ ...book, inLibrary: false }))
    const [books, sagas, catalogue] = await Promise.all([
      BookQuery.withSignedCovers(picks.books.map((pick) => pick.item)),
      Promise.all(
        picks.sagas.map((pick) =>
          BookQuery.withSignedCovers(inReadingOrder(pick.item.books).slice(0, 1)),
        ),
      ),
      AuthorQuery.byKeys(picks.authors.map((pick) => pick.item.key)),
    ])
    const portraits = new Map(catalogue.map((author) => [author.key, author.portraitUrl]))
    return {
      books: picks.books.flatMap((pick, index) => {
        const book = books[index]
        return book ? [loved(pick, { ...book, inLibrary: false })] : []
      }),
      sagas: picks.sagas.map((pick, index) => {
        const shelf = byFriend.get(pick.friendId)
        return loved(
          pick,
          friendSagaOf(
            pick.item,
            shelf?.favoriteSagas ?? new Map(),
            shelf?.ratings ?? new Map(),
            unowned(sagas[index] ?? []),
          ),
        )
      }),
      authors: picks.authors.map((pick) => {
        const portraitUrl = portraits.get(pick.item.key)
        return loved(pick, { ...pick.item, ...(portraitUrl ? { portraitUrl } : {}) })
      }),
    }
  }

  /** Whether the reader may take a friend's book as an audiobook: a
   *  recording is, and a printed book is when Audible sells it in its
   *  language under the same title and author. Null for a stranger's book, a
   *  book that does not exist and a book marked "do not share" alike. */
  export const audio = async (
    userId: UserId,
    friendId: UserId,
    bookId: BookId,
  ): Promise<AudioAvailability | null> => {
    const source = await book(userId, friendId, bookId)
    if (!source) return null
    if (source.format === 'audiobook') return 'available'
    if (!source.language) return 'unknown'
    const recording = await DiscoveryUseCase.audioEditionOf(
      source.title,
      source.authors[0],
      source.language,
    )
    return recording === 'unreachable'
      ? 'unknown'
      : recording === 'unknown'
        ? 'unavailable'
        : 'available'
  }

  /** What the page of a friend's book offers to await: its edition in the
   *  app's language, translated or recorded — and, for a printed book already
   *  in that language, its recording.
   *  Null for a stranger's book, a book that does not exist and a book marked
   *  "do not share" alike. */
  export const editionOffer = async (
    userId: UserId,
    friendId: UserId,
    bookId: BookId,
    appLanguage: Language,
  ): Promise<EditionOffer | null> => {
    const source = await book(userId, friendId, bookId)
    if (!source) return null
    return AwaitedEditionUseCase.offerFor(userId, source, friendId, appLanguage)
  }

  /** Await a friend's book in the app's language, in one format. */
  export const awaitEdition = async (
    userId: UserId,
    friendId: UserId,
    bookId: BookId,
    format: ReleaseFormat,
    appLanguage: Language,
  ): Promise<AwaitOutcome> => {
    const source = await book(userId, friendId, bookId)
    if (!source) return 'not-found'
    return AwaitedEditionUseCase.awaitBook(userId, source, friendId, format, appLanguage)
  }

  /** Put a friend's book on the reader's own shelf.
   *
   *  Only the friend and the book are named: the record is re-read here and
   *  its catalogue facts copied, never taken from the client, as the imports
   *  do. What the friend made of it stays theirs — no status, rating, heart,
   *  note, nor their cover photo, which lives under their account. The copy
   *  remembers who it came from as its recommendation, which the reader can
   *  correct afterwards like any other.
   *
   *  `format` is how the reader takes the story in, which need not be how the
   *  friend does: a reader who never listens takes a friend's recording as a
   *  book. Across that line the facts of the other object are dropped — a
   *  running time and narrators say nothing of a printed book, a page count
   *  nothing of a recording — and the volume moves to the saga of its format.
   *  A printed book taken heard takes its narrators, running time and cover
   *  from the recording Audible sells, when it sells one. */
  export const copyBook = async (
    userId: UserId,
    friendId: UserId,
    bookId: BookId,
    status: CopiedStatus,
    format?: BookFormat,
    media?: BookMedium[],
  ): Promise<Book | 'not-found' | 'already-owned'> => {
    const source = await book(userId, friendId, bookId)
    if (!source) return 'not-found'
    if (source.inLibrary) return 'already-owned'
    const taken = format ?? source.format
    const heard = taken === 'audiobook'
    const sameMedium = heard === (source.format === 'audiobook')
    // A printed book taken heard is described by the recording Audible sells,
    // when it sells one: who reads it, how long it runs, its square cover.
    const [names, found] = await Promise.all([
      UserQuery.namesOf([friendId]),
      heard && !sameMedium && source.language
        ? DiscoveryUseCase.audioEditionOf(source.title, source.authors[0], source.language)
        : undefined,
    ])
    const firstName = names.get(friendId)
    const recording = typeof found === 'object' ? found : undefined
    return BookUseCase.add(userId, {
      title: source.title,
      authors: source.authors,
      format: taken,
      // Held the way the friend holds it, unless the reader said otherwise.
      media: media ?? (taken === source.format ? source.media : undefined),
      publisher: source.publisher,
      firstPublishedIn: source.firstPublishedIn,
      synopsis: source.synopsis,
      genre: source.genre,
      subgenres: source.subgenres,
      pageCount: sameMedium ? source.pageCount : undefined,
      durationMinutes: sameMedium ? source.durationMinutes : recording?.durationMinutes,
      narrators: sameMedium ? source.narrators : (recording?.narrators ?? []),
      isbn13: source.isbn13,
      language: source.language,
      series: source.series,
      publishedCoverUrl: recording?.coverUrl ?? source.kindleCoverUrl ?? source.publishedCoverUrl,
      status,
      recommendation: firstName ? { recommenderName: PersonName(firstName) } : undefined,
    })
  }
}

/** Whether `viewerId` may read `ownerId`'s shelf: a friend's, or their own,
 *  previewed as their friends see it. */
const canRead = async (viewerId: UserId, ownerId: UserId): Promise<boolean> =>
  viewerId === ownerId || (await FriendshipQuery.areFriends(viewerId, ownerId))

/** The latest day one of a saga's volumes was shelved on. */
const sagaShelvedAt = (saga: FollowedSaga<Book>): Date =>
  new Date(Math.max(...saga.books.map((book) => shelfDateOf(book).getTime())))

/** A saga as a friend sees it, with the volumes signed for it, if any. */
const friendSagaOf = (
  saga: FollowedSaga<Book>,
  favoriteSagas: ReadonlyMap<SeriesId, Date | undefined>,
  ratings: ReadonlyMap<SeriesId, StarRating>,
  volumes: FriendBook[],
): FriendSaga => {
  const genre = genreOf(saga.books)
  return {
    id: `${saga.id}\u0000${saga.language ?? ''}`,
    seriesId: saga.id,
    name: saga.name,
    author: saga.author,
    language: saga.language,
    ownedCount: Count(saga.books.length),
    favorite: favoriteSagas.has(saga.id),
    favoritedAt: favoriteSagas.get(saga.id),
    rating: ratings.get(saga.id),
    genre,
    subgenre: subgenreOf(saga.books, genre),
    volumes,
    shelvedAt: sagaShelvedAt(saga),
    state: friendSagaStateOf(saga.books),
  }
}

/** The hearted sagas of a shelf, with the day of each heart. */
const favoriteSagasOf = async (ownerId: UserId): Promise<Map<SeriesId, Date | undefined>> =>
  new Map(
    (await SeriesOpinionQuery.all(ownerId))
      .filter((opinion) => opinion.favorite)
      .map((opinion) => [opinion.seriesId, opinion.favoritedAt]),
  )

/** The stars a shelf's owner gave their sagas. The opinions are scanned once
 *  per request, whichever of this and the hearts asks first. */
const sagaRatingsOf = async (ownerId: UserId): Promise<Map<SeriesId, StarRating>> =>
  seriesRatingsOf(await SeriesOpinionQuery.all(ownerId))

/** One reader's shelf as it is shared: what they are reading, most recently
 *  active first; their pile, newest first; their hearts; their sagas. At most
 *  `shown` of each list of books when given. Whether the viewer owns each
 *  book is left to `marked`, so the two reads can run side by side. */
const sharedShelfOf = async (
  ownerId: UserId,
  shown = Number.POSITIVE_INFINITY,
): Promise<FriendProfile> => {
  const [books, favoriteSagas, ratings, names, figures] = await Promise.all([
    BookQuery.shared(ownerId),
    favoriteSagasOf(ownerId),
    sagaRatingsOf(ownerId),
    UserQuery.namesOf([ownerId]),
    AnalyticsUseCase.sharedShelves([ownerId]),
  ])
  const favoriteSagaIds = new Set(favoriteSagas.keys())
  const reading = books
    .filter((book) => book.status === 'reading')
    .sort((left, right) => lastActivityOf(right).getTime() - lastActivityOf(left).getTime())
    .slice(0, shown)
  const pile = books
    .filter((book) => book.status === 'to-read')
    .sort((left, right) => right.addedAt.getTime() - left.addedAt.getTime())
    .slice(0, shown)
  const favorites = newestFavoritesFirst(
    favoritesOutsideSagas(
      books.filter((book) => book.favorite === true),
      favoriteSagaIds,
    ),
  ).slice(0, shown)

  const finished = lastFinishedOf(books)
  const dropped = lastDroppedOf(books)
  const added = lastAddedOf(books)
  // The sagas drawn with their covers: the favourites, and those of the
  // books the recent activity leads with — the one in progress, the last
  // finished, the last hearted.
  const drawnSagaIds = new Set(
    [
      ...favoriteSagaIds,
      reading[0]?.series?.id,
      finished?.series?.id,
      favorites[0]?.series?.id,
    ].filter((id): id is SeriesId => id !== undefined),
  )

  const sagas = followedSagasOf(books)
  const [
    signedReading,
    signedPile,
    signedFavorites,
    signedVolumes,
    signedFinished,
    signedDropped,
    signedAdded,
  ] = await Promise.all([
    BookQuery.withSignedCovers(reading),
    BookQuery.withSignedCovers(pile),
    BookQuery.withSignedCovers(favorites),
    Promise.all(
      sagas.map((saga) =>
        drawnSagaIds.has(saga.id)
          ? BookQuery.withSignedCovers(inReadingOrder(saga.books))
          : Promise.resolve([]),
      ),
    ),
    BookQuery.withSignedCovers(finished ? [finished] : []),
    BookQuery.withSignedCovers(dropped ? [dropped] : []),
    BookQuery.withSignedCovers(added ? [added] : []),
  ])
  const unmarked = (books: BookView[]): FriendBook[] =>
    books.map((book) => ({ ...book, inLibrary: false }))

  return {
    userId: ownerId,
    firstName: names.get(ownerId),
    reading: unmarked(signedReading),
    pile: unmarked(signedPile),
    favorites: unmarked(signedFavorites),
    lastFinished: unmarked(signedFinished)[0],
    lastDropped: unmarked(signedDropped)[0],
    lastAdded: unmarked(signedAdded)[0],
    sagas: sagas.map((saga, index) =>
      friendSagaOf(saga, favoriteSagas, ratings, unmarked(signedVolumes[index] ?? [])),
    ),
    bookCount: Count(books.filter((book) => SHELVED_STATUSES.includes(book.status)).length),
    readThisYear: Count(figures.get(ownerId)?.readThisYear ?? 0),
  }
}

/** The shelf with each book saying whether the viewer already owns it. */
const marked = (shelf: FriendProfile, inLibrary: (book: FriendBook) => boolean): FriendProfile => {
  const mark = (books: FriendBook[]) =>
    books.map((book) => ({ ...book, inLibrary: inLibrary(book) }))
  return {
    ...shelf,
    reading: mark(shelf.reading),
    pile: mark(shelf.pile),
    favorites: mark(shelf.favorites),
    lastFinished: shelf.lastFinished && mark([shelf.lastFinished])[0],
    lastDropped: shelf.lastDropped && mark([shelf.lastDropped])[0],
    lastAdded: shelf.lastAdded && mark([shelf.lastAdded])[0],
    sagas: shelf.sagas.map((saga) => ({ ...saga, volumes: mark(saga.volumes) })),
  }
}

const ownsStory = (owned: ReadonlySet<string>, book: Pick<Book, 'title' | 'authors'>): boolean =>
  owned.has(shelfKeyOf(book.title, book.authors[0]))
