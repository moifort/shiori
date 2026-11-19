import type { UserId } from '~/domain/shared/types'
import { friendOriginOf } from '~/domain/wish/business-rules'
import * as repository from '~/domain/wish/infrastructure/repository'
import type { Wish, WishedBook, WishOrigin } from '~/domain/wish/types'

export namespace WishQuery {
  export const byUser = (userId: UserId): Promise<Wish[]> => repository.findAllByUser(userId)

  /** The friend a story was wished for at, if it was: read before the book's
   *  arrival deletes its wish, so the book keeps who showed it. */
  export const friendBehind = async (
    userId: UserId,
    book: Pick<WishedBook, 'title' | 'authors'>,
  ): Promise<WishOrigin | undefined> => friendOriginOf(await byUser(userId), userId, book)
}
