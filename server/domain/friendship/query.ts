import * as repository from '~/domain/friendship/infrastructure/repository'
import type { Friendship } from '~/domain/friendship/types'
import type { UserId } from '~/domain/shared/types'

export namespace FriendshipQuery {
  export const all = (userId: UserId): Promise<Friendship[]> => repository.findAllByUser(userId)

  /** The other half of every friendship the reader is in. */
  export const friendsOf = async (userId: UserId): Promise<UserId[]> =>
    (await all(userId)).flatMap((friendship) =>
      friendship.userIds.filter((member) => member !== userId),
    )

  /** Whether one reader may read another's library at all. Every read of
   *  somebody else's books goes through this. */
  export const areFriends = async (userId: UserId, otherId: UserId): Promise<boolean> =>
    (await friendsOf(userId)).includes(otherId)
}
