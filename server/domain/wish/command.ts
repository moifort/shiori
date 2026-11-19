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
   *  edit — so the wishlist never deletes while it is read. The reader's
   *  wishes are read first, once a request — an arrival has read them already,
   *  for the friend behind the wish — and only a story wished for is deleted:
   *  a sync shelving book after book keeps the list it read. */
  export const forgetHeld = async (
    userId: UserId,
    books: readonly Pick<Book, 'title' | 'authors'>[],
    batch?: WriteBatch,
  ): Promise<void> => {
    const wished = new Set((await repository.findAllByUser(userId)).map((wish) => wish.id))
    const held = books.map((book) => wishIdOf(userId, book)).filter((id) => wished.has(id))
    if (held.length > 0) await repository.remove(userId, held, batch)
  }

  export const deleteAllForUser = (userId: UserId): Promise<void> =>
    repository.removeAllByUser(userId)
}
