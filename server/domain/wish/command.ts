import type { WriteBatch } from 'firebase-admin/firestore'
import type { Book } from '~/domain/book/types'
import type { UserId } from '~/domain/shared/types'
import { wishIdOf } from '~/domain/wish/business-rules'
import * as repository from '~/domain/wish/infrastructure/repository'
import type { Wish, WishId } from '~/domain/wish/types'

export namespace WishCommand {
  export const save = (wish: Wish): Promise<Wish> => repository.save(wish)

  /** Only the reader's own are named, so an id of somebody else's is simply
   *  not found among them. */
  export const remove = (userId: UserId, ids: readonly WishId[]): Promise<void> =>
    repository.remove(userId, ids)

  /** A story the library now holds is no longer wished for: its wish goes
   *  for good, even if the book leaves the library later. Called by every
   *  write that sets a book's title or first author — an arrival, a merge, an
   *  edit — so the wishlist never deletes while it is read. A wish's id is its
   *  story's, so nothing is read: a story never wished for costs one delete. */
  export const forgetHeld = (
    userId: UserId,
    books: readonly Pick<Book, 'title' | 'authors'>[],
    batch?: WriteBatch,
  ): Promise<void> =>
    repository.remove(
      userId,
      books.map((book) => wishIdOf(userId, book)),
      batch,
    )

  export const deleteAllForUser = (userId: UserId): Promise<void> =>
    repository.removeAllByUser(userId)
}
