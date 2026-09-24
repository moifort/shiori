import { AnalyticsUseCase } from '~/domain/analytics/use-case'
import { shelfDateOf, shelfKeyOf, shelfPageOf, shelvedOf } from '~/domain/book/business-rules'
import { BookQuery } from '~/domain/book/query'
import type {
  Book,
  BookId,
  BookLanguage,
  BookView,
  Genre,
  ReadingStatus,
  TaggedSubgenre,
} from '~/domain/book/types'
import { READING_STATUSES } from '~/domain/book/types'
import { BookUseCase } from '~/domain/book/use-case'
import {
  favoritesOutsideSagas,
  friendSagaStateOf,
  inReadingOrder,
  lastActivityOf,
  lastFinishedOf,
  newestFavoritesFirst,
  subgenreOf,
} from '~/domain/friendship/business-rules'
import { FriendshipQuery } from '~/domain/friendship/query'
import type { Friend } from '~/domain/friendship/types'
import { type FollowedSaga, followedSagasOf, genreOf } from '~/domain/series/business-rules'
import type { SeriesId, SeriesName, SeriesState } from '~/domain/series/types'
import { SeriesOpinionQuery } from '~/domain/series-opinion/query'
import { Count, PersonName } from '~/domain/shared/primitives'
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
  /** How many books their library shows — every one they share, the
   *  dropped ones aside, as the reader's own Library tab. */
  bookCount: CountValue
}

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
   *  every volume on the shelf as a cover. `after` is the id of the last saga
   *  of the previous page. Null for a stranger. */
  export const sagaPage = async (
    viewerId: UserId,
    ownerId: UserId,
    page: { limit: number; after?: string },
    view: { state?: SeriesState; favorite?: boolean } = {},
  ): Promise<FriendSagaPage | null> => {
    if (!(await canRead(viewerId, ownerId))) return null
    const [books, favoriteSagas, owned] = await Promise.all([
      BookQuery.shared(ownerId),
      favoriteSagasOf(ownerId),
      BookQuery.shelfKeys(viewerId),
    ])
    const sagas = followedSagasOf(books)
      .filter(
        (saga) =>
          (!view.state || friendSagaStateOf(saga.books) === view.state) &&
          (!view.favorite || favoriteSagas.has(saga.id)),
      )
      .map((saga) => ({ saga, id: `${saga.id}\u0000${saga.language ?? ''}` }))
      .sort(
        (left, right) =>
          sagaShelvedAt(right.saga).getTime() - sagaShelvedAt(left.saga).getTime() ||
          left.saga.name.localeCompare(right.saga.name),
      )
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
          (volumes[index] ?? []).map((book) => ({ ...book, inLibrary: ownsStory(owned, book) })),
        ),
      ),
      hasMore: start + page.limit < sagas.length,
    }
  }

  /** Put a friend's book on the reader's own shelf.
   *
   *  Only the friend and the book are named: the record is re-read here and
   *  its catalogue facts copied, never taken from the client, as the imports
   *  do. What the friend made of it stays theirs — no status, rating, heart,
   *  note, nor their cover photo, which lives under their account. The copy
   *  remembers who it came from as its recommendation, which the reader can
   *  correct afterwards like any other. */
  export const copyBook = async (
    userId: UserId,
    friendId: UserId,
    bookId: BookId,
    status: CopiedStatus,
  ): Promise<Book | 'not-found' | 'already-owned'> => {
    const source = await book(userId, friendId, bookId)
    if (!source) return 'not-found'
    if (source.inLibrary) return 'already-owned'
    const firstName = (await UserQuery.namesOf([friendId])).get(friendId)
    return BookUseCase.add(userId, {
      title: source.title,
      authors: source.authors,
      format: source.format,
      publisher: source.publisher,
      firstPublishedIn: source.firstPublishedIn,
      synopsis: source.synopsis,
      genre: source.genre,
      subgenres: source.subgenres,
      pageCount: source.pageCount,
      durationMinutes: source.durationMinutes,
      narrators: source.narrators,
      isbn13: source.isbn13,
      language: source.language,
      series: source.series,
      publishedCoverUrl: source.publishedCoverUrl,
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

/** One reader's shelf as it is shared: what they are reading, most recently
 *  active first; their pile, newest first; their hearts; their sagas. At most
 *  `shown` of each list of books when given. Whether the viewer owns each
 *  book is left to `marked`, so the two reads can run side by side. */
const sharedShelfOf = async (
  ownerId: UserId,
  shown = Number.POSITIVE_INFINITY,
): Promise<FriendProfile> => {
  const [books, favoriteSagas, names] = await Promise.all([
    BookQuery.shared(ownerId),
    favoriteSagasOf(ownerId),
    UserQuery.namesOf([ownerId]),
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
  const [signedReading, signedPile, signedFavorites, signedVolumes, signedFinished] =
    await Promise.all([
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
    sagas: sagas.map((saga, index) =>
      friendSagaOf(saga, favoriteSagas, unmarked(signedVolumes[index] ?? [])),
    ),
    bookCount: Count(books.filter((book) => SHELVED_STATUSES.includes(book.status)).length),
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
    sagas: shelf.sagas.map((saga) => ({ ...saga, volumes: mark(saga.volumes) })),
  }
}

const ownsStory = (owned: ReadonlySet<string>, book: Pick<Book, 'title' | 'authors'>): boolean =>
  owned.has(shelfKeyOf(book.title, book.authors[0]))
