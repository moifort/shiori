import type { UserId } from '~/domain/shared/types'
import * as repository from '~/domain/wish/infrastructure/repository'
import type { Wish, WishId } from '~/domain/wish/types'

export namespace WishCommand {
  export const save = (wish: Wish): Promise<Wish> => repository.save(wish)

  /** Only the reader's own are named, so an id of somebody else's is simply
   *  not found among them. */
  export const remove = (userId: UserId, ids: readonly WishId[]): Promise<void> =>
    repository.remove(userId, ids)

  export const deleteAllForUser = (userId: UserId): Promise<void> =>
    repository.removeAllByUser(userId)
}
