import { authorKeyOf } from '~/domain/author/primitives'
import type { AuthorKey } from '~/domain/author/types'
import { shelfKeyOf } from '~/domain/book/business-rules'
import type { Book, Genre, TaggedSubgenre } from '~/domain/book/types'
import { seriesIdFor } from '~/domain/series/primitives'
import type { SeriesId, SeriesState } from '~/domain/series/types'
import type { AuthorName, UserId } from '~/domain/shared/types'

/** When the reader last did anything with a book: picked it up, moved its
 *  status, or had a sync move its listening position. What "most recently
 *  active first" orders on, falling back through the older stamps for records
 *  written before the newer ones existed. */
export const lastActivityOf = (
  book: Pick<Book, 'addedAt' | 'updatedAt' | 'statusChangedAt' | 'startedAt'>,
): Date =>
  new Date(
    Math.max(
      book.addedAt.getTime(),
      book.updatedAt?.getTime() ?? 0,
      book.statusChangedAt?.getTime() ?? 0,
      book.startedAt?.getTime() ?? 0,
    ),
  )

/** The book finished most recently: the one a friend coming back would ask
 *  about. Only a book with a finishing date counts — one filed as read with no
 *  date says nothing about when. */
export const lastFinishedOf = <Finished extends Pick<Book, 'status' | 'finishedAt'>>(
  books: readonly Finished[],
): Finished | undefined =>
  books
    .filter((book) => book.status === 'read' && book.finishedAt !== undefined)
    .reduce<Finished | undefined>(
      (latest, book) =>
        !latest || (book.finishedAt?.getTime() ?? 0) > (latest.finishedAt?.getTime() ?? 0)
          ? book
          : latest,
      undefined,
    )

/** The favourites newest first: the most recently hearted leads, so a friend
 *  who comes back finds what is new at the top rather than the same list. A
 *  heart given before its date was kept ranks on the book's last activity,
 *  which is always older than any dated heart. */
export const newestFavoritesFirst = <
  Favorite extends Pick<
    Book,
    'favoritedAt' | 'addedAt' | 'updatedAt' | 'statusChangedAt' | 'startedAt'
  >,
>(
  favorites: readonly Favorite[],
): Favorite[] => {
  const heartedAt = (book: Favorite) => (book.favoritedAt ?? lastActivityOf(book)).getTime()
  return [...favorites].sort((left, right) => heartedAt(right) - heartedAt(left))
}

/** The hearted books that are not already shown through a hearted saga.
 *
 *  A favourite saga stands for its volumes: listing one of them again among the
 *  favourite books would say the same thing twice, and a list shared with
 *  somebody else would carry the volume twice. */
export const favoritesOutsideSagas = <Favorite extends Pick<Book, 'series'>>(
  favorites: readonly Favorite[],
  favoriteSagaIds: ReadonlySet<SeriesId>,
): Favorite[] => favorites.filter((book) => !book.series || !favoriteSagaIds.has(book.series.id))

/** The subgenre a saga is described by: the leading subgenre of the first
 *  volume that carries the saga's genre, so the pair reads as one description
 *  rather than two facts taken from different books. */
export const subgenreOf = (
  books: readonly { genre?: Genre; subgenres: readonly TaggedSubgenre[] }[],
  genre: Genre | undefined,
): TaggedSubgenre | undefined =>
  books.find((book) => book.genre === genre && book.subgenres.length > 0)?.subgenres[0]

/** A saga's volumes on the shelf in reading order: main volumes by number,
 *  then the rest — prequels, novellas, spin-offs — by number, an unnumbered
 *  volume last in its group. */
export const inReadingOrder = <Volume extends Pick<Book, 'series'>>(
  volumes: readonly Volume[],
): Volume[] =>
  [...volumes].sort(
    (left, right) =>
      Number(left.series?.kind !== 'main') - Number(right.series?.kind !== 'main') ||
      (left.series?.volume ?? Number.POSITIVE_INFINITY) -
        (right.series?.volume ?? Number.POSITIVE_INFINITY),
  )

/** Where a friend stands on a saga, read off the volumes on their shelf alone
 *  — how many the saga has is the catalogue's, which a friendship does not
 *  open: none opened is not started, every one read is complete, anything
 *  else in progress. */
export const friendSagaStateOf = (
  volumes: readonly Pick<Book, 'status'>[],
): Exclude<SeriesState, 'unfollowed'> => {
  if (volumes.every((volume) => volume.status === 'to-read')) return 'not-started'
  if (volumes.every((volume) => volume.status === 'read')) return 'complete'
  return 'in-progress'
}

/** A heart one friend gave lately: to a saga, or to a book no hearted saga of
 *  theirs already stands for. */
export type RecentHeart<Favorite, Saga> = { friendId: UserId; favoritedAt: Date } & (
  | { book: Favorite; saga?: never }
  | { saga: Saga; book?: never }
)

const newestHeartFirst = (left: { favoritedAt: Date }, right: { favoritedAt: Date }) =>
  right.favoritedAt.getTime() - left.favoritedAt.getTime()

/** The last heart each friend gave since `since`, the newest first, `limit`
 *  at most: what the dashboard shows as news from the people the reader shares
 *  with, one tile per friend so a busy shelf does not crowd out the others.
 *  Only a dated heart counts — one given before the date was kept says nothing
 *  about being new. A saga held in two languages is hearted once. */
export const recentHeartsOf = <
  Favorite extends Pick<Book, 'favorite' | 'favoritedAt' | 'series'>,
  Saga extends { id: SeriesId },
>(
  shelves: readonly {
    friendId: UserId
    books: readonly Favorite[]
    sagas: readonly Saga[]
    favoriteSagas: ReadonlyMap<SeriesId, Date | undefined>
  }[],
  since: Date,
  limit: number,
): RecentHeart<Favorite, Saga>[] => {
  const isRecent = (date: Date | undefined): date is Date =>
    date !== undefined && date.getTime() >= since.getTime()
  const hearts = shelves.flatMap(({ friendId, books, sagas, favoriteSagas }) => {
    const seen = new Set<SeriesId>()
    const sagaHearts = sagas.flatMap((saga): RecentHeart<Favorite, Saga>[] => {
      const favoritedAt = favoriteSagas.get(saga.id)
      if (!isRecent(favoritedAt) || seen.has(saga.id)) return []
      seen.add(saga.id)
      return [{ friendId, favoritedAt, saga }]
    })
    const bookHearts = favoritesOutsideSagas(
      books.filter((book) => book.favorite === true),
      new Set(favoriteSagas.keys()),
    ).flatMap((book): RecentHeart<Favorite, Saga>[] =>
      isRecent(book.favoritedAt) ? [{ friendId, favoritedAt: book.favoritedAt, book }] : [],
    )
    return [...sagaHearts, ...bookHearts].sort(newestHeartFirst).slice(0, 1)
  })
  return hearts.sort(newestHeartFirst).slice(0, limit)
}

// MARK: - What the friends love that the reader does not hold

/** Whether enough friends love one thing for Découvrir to flame it: a third of
 *  them, and never fewer than two — one heart is a friend's taste, not a
 *  trend, however few friends the reader has. */
export const isLovedByMany = (lovers: number, friendCount: number): boolean =>
  lovers >= Math.max(2, Math.ceil(friendCount / 3))

/** One thing some friends hearted, folded across them: the copy of the friend
 *  who hearted it last stands for it, and `friendIds` lists who loves it, the
 *  newest heart first. */
export type FriendPick<Item> = {
  item: Item
  friendId: UserId
  friendIds: UserId[]
  lovedAt: Date
  lovedByMany: boolean
}

type Heart<Item> = { friendId: UserId; key: string; item: Item; lovedAt: Date }

/** The hearts folded by what they are about, the newest heart first, leaving
 *  out what the reader holds already. */
const picksOf = <Item>(
  hearts: readonly Heart<Item>[],
  held: ReadonlySet<string>,
  friendCount: number,
  limit: number,
): FriendPick<Item>[] => {
  const picks = new Map<string, FriendPick<Item>>()
  const newestFirst = [...hearts].sort(
    (left, right) => right.lovedAt.getTime() - left.lovedAt.getTime(),
  )
  for (const heart of newestFirst) {
    if (held.has(heart.key)) continue
    const known = picks.get(heart.key)
    if (!known) {
      picks.set(heart.key, {
        item: heart.item,
        friendId: heart.friendId,
        friendIds: [heart.friendId],
        lovedAt: heart.lovedAt,
        lovedByMany: false,
      })
    } else if (!known.friendIds.includes(heart.friendId)) {
      known.friendIds.push(heart.friendId)
    }
  }
  return [...picks.values()]
    .slice(0, limit)
    .map((pick) => ({ ...pick, lovedByMany: isLovedByMany(pick.friendIds.length, friendCount) }))
}

/** An author as the friends' hearts name them. */
export type PickedAuthor = { key: AuthorKey; name: AuthorName }

type PickedBook = Pick<
  Book,
  | 'title'
  | 'authors'
  | 'favorite'
  | 'favoritedAt'
  | 'series'
  | 'addedAt'
  | 'updatedAt'
  | 'statusChangedAt'
  | 'startedAt'
>

/** What the reader's friends love and the reader does not hold, for Découvrir:
 *  the books they hearted, the sagas they hearted and the authors of both, each
 *  the newest heart first, `limit` of each at most.
 *
 *  Held is judged on the story, never on the format: a book the reader owns in
 *  any format, a saga they hold a volume of read or heard, an author they hold
 *  any book of. A friend's recording is a story the reader may take on paper,
 *  and the other way round. A heart given before its date was kept ranks on
 *  the last activity of what it is on, older than any dated heart. */
export const friendPicksOf = <
  Favorite extends PickedBook,
  Saga extends { id: SeriesId; books: readonly Favorite[] },
>(
  shelves: readonly {
    friendId: UserId
    books: readonly Favorite[]
    sagas: readonly Saga[]
    favoriteSagas: ReadonlyMap<SeriesId, Date | undefined>
  }[],
  held: readonly Pick<Book, 'title' | 'authors' | 'series'>[],
  limit: number,
): {
  books: FriendPick<Favorite>[]
  sagas: FriendPick<Saga>[]
  authors: FriendPick<PickedAuthor>[]
} => {
  const heldStories = new Set(held.map((book) => shelfKeyOf(book.title, book.authors[0])))
  const heldSagas = new Set(
    held.flatMap((book) => (book.series ? [seriesIdFor(book.series.id, 'book')] : [])),
  )
  const heldAuthors = new Set<string>(held.flatMap((book) => book.authors.map(authorKeyOf)))

  const bookHearts: Heart<Favorite>[] = []
  const sagaHearts: Heart<Saga>[] = []
  const authorHearts: Heart<PickedAuthor>[] = []
  const loveAuthorsOf = (friendId: UserId, book: Favorite, lovedAt: Date) => {
    for (const name of book.authors)
      authorHearts.push({
        friendId,
        key: authorKeyOf(name),
        item: { key: authorKeyOf(name), name },
        lovedAt,
      })
  }
  for (const { friendId, books, sagas, favoriteSagas } of shelves) {
    for (const book of books) {
      if (book.favorite !== true) continue
      const lovedAt = book.favoritedAt ?? lastActivityOf(book)
      bookHearts.push({
        friendId,
        key: shelfKeyOf(book.title, book.authors[0]),
        item: book,
        lovedAt,
      })
      loveAuthorsOf(friendId, book, lovedAt)
    }
    for (const saga of sagas) {
      if (!favoriteSagas.has(saga.id) || saga.books.length === 0) continue
      const lovedAt =
        favoriteSagas.get(saga.id) ??
        new Date(Math.max(...saga.books.map((book) => lastActivityOf(book).getTime())))
      sagaHearts.push({ friendId, key: seriesIdFor(saga.id, 'book'), item: saga, lovedAt })
      for (const book of saga.books) loveAuthorsOf(friendId, book, lovedAt)
    }
  }
  const friendCount = shelves.length
  return {
    books: picksOf(bookHearts, heldStories, friendCount, limit),
    sagas: picksOf(sagaHearts, heldSagas, friendCount, limit),
    authors: picksOf(authorHearts, heldAuthors, friendCount, limit),
  }
}
