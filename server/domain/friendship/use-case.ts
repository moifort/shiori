import { BookQuery } from '~/domain/book/query'
import type { BookLanguage, BookView } from '~/domain/book/types'
import { FriendshipQuery } from '~/domain/friendship/query'
import type { Friend } from '~/domain/friendship/types'
import { followedSagasOf } from '~/domain/series/business-rules'
import type { SeriesName } from '~/domain/series/types'
import { Count } from '~/domain/shared/primitives'
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
  name: SeriesName
  author?: AuthorName
  language?: BookLanguage
  ownedCount: CountValue
}

/** A friend's shelf, as the profile screen draws it. */
export type FriendProfile = {
  userId: UserId
  firstName?: string
  reading: BookView[]
  pile: BookView[]
  favorites: BookView[]
  sagas: FriendSaga[]
}

export namespace FriendshipUseCase {
  /** The reader's friends, named. One scan of the friendships and one batched
   *  read of the profiles behind them — never a read per row. */
  export const friends = async (userId: UserId): Promise<Friend[]> => {
    const friendships = await FriendshipQuery.all(userId)
    const others = friendships.map((friendship) => ({
      friendship,
      userId: friendship.userIds.find((member) => member !== userId),
    }))
    const names = await UserQuery.namesOf(
      others.flatMap((entry) => (entry.userId ? [entry.userId] : [])),
    )
    return others
      .flatMap((entry) =>
        entry.userId
          ? [
              {
                userId: entry.userId,
                firstName: names.get(entry.userId),
                since: entry.friendship.since,
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

    const books = await BookQuery.shared(friendId)
    const reading = books
      .filter((book) => book.status === 'reading')
      .sort(
        (left, right) =>
          (right.startedAt ?? right.addedAt).getTime() - (left.startedAt ?? left.addedAt).getTime(),
      )
      .slice(0, SHELF_SHOWN)
    const pile = books
      .filter((book) => book.status === 'to-read')
      .sort((left, right) => right.addedAt.getTime() - left.addedAt.getTime())
      .slice(0, SHELF_SHOWN)
    const favorites = books.filter((book) => book.favorite === true).slice(0, SHELF_SHOWN)

    const [signedReading, signedPile, signedFavorites] = await Promise.all([
      BookQuery.withSignedCovers(reading),
      BookQuery.withSignedCovers(pile),
      BookQuery.withSignedCovers(favorites),
    ])

    return {
      userId: friendId,
      firstName: (await UserQuery.namesOf([friendId])).get(friendId),
      reading: signedReading,
      pile: signedPile,
      favorites: signedFavorites,
      sagas: followedSagasOf(books).map((saga) => ({
        id: `${saga.id}\u0000${saga.language ?? ''}`,
        name: saga.name,
        author: saga.author,
        language: saga.language,
        ownedCount: Count(saga.books.length),
      })),
    }
  }
}
