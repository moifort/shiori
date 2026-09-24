import { AnalyticsUseCase } from '~/domain/analytics/use-case'
import { shelfKeyOf } from '~/domain/book/business-rules'
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
import { BookUseCase } from '~/domain/book/use-case'
import {
  favoritesOutsideSagas,
  inReadingOrder,
  lastActivityOf,
  lastFinishedOf,
  newestFavoritesFirst,
  subgenreOf,
} from '~/domain/friendship/business-rules'
import { FriendshipQuery } from '~/domain/friendship/query'
import type { Friend } from '~/domain/friendship/types'
import { followedSagasOf, genreOf } from '~/domain/series/business-rules'
import type { SeriesId, SeriesName } from '~/domain/series/types'
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
  /** Its volumes on the shelf, in reading order, for the favourites to draw
   *  as a strip of covers. Empty on a saga that is not hearted: each cover is
   *  a signed URL, and only the favourites draw them. */
  volumes: FriendBook[]
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
}

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
   *  not share" alike. */
  export const book = async (
    userId: UserId,
    friendId: UserId,
    bookId: BookId,
  ): Promise<FriendBook | null> => {
    if (!(await FriendshipQuery.areFriends(userId, friendId))) return null
    const [book, owned] = await Promise.all([
      BookQuery.sharedById(friendId, bookId),
      BookQuery.shelfKeys(userId),
    ])
    return book ? { ...book, inLibrary: ownsStory(owned, book) } : null
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

/** One reader's shelf as it is shared: what they are reading, most recently
 *  active first; their pile, newest first; their hearts; their sagas. At most
 *  `shown` of each list of books when given. Whether the viewer owns each
 *  book is left to `marked`, so the two reads can run side by side. */
const sharedShelfOf = async (
  ownerId: UserId,
  shown = Number.POSITIVE_INFINITY,
): Promise<FriendProfile> => {
  const [books, opinions, names] = await Promise.all([
    BookQuery.shared(ownerId),
    SeriesOpinionQuery.all(ownerId),
    UserQuery.namesOf([ownerId]),
  ])
  const favoriteSagas = new Map(
    opinions
      .filter((opinion) => opinion.favorite)
      .map((opinion) => [opinion.seriesId, opinion.favoritedAt]),
  )
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

  const sagas = followedSagasOf(books)
  const [signedReading, signedPile, signedFavorites, signedVolumes, signedFinished] =
    await Promise.all([
      BookQuery.withSignedCovers(reading),
      BookQuery.withSignedCovers(pile),
      BookQuery.withSignedCovers(favorites),
      Promise.all(
        sagas.map((saga) =>
          favoriteSagaIds.has(saga.id)
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
    sagas: sagas.map((saga, index) => {
      const genre = genreOf(saga.books)
      return {
        id: `${saga.id}\u0000${saga.language ?? ''}`,
        seriesId: saga.id,
        name: saga.name,
        author: saga.author,
        language: saga.language,
        ownedCount: Count(saga.books.length),
        favorite: favoriteSagaIds.has(saga.id),
        favoritedAt: favoriteSagas.get(saga.id),
        genre,
        subgenre: subgenreOf(saga.books, genre),
        volumes: unmarked(signedVolumes[index] ?? []),
      }
    }),
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
