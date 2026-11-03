import { BookQuery } from '~/domain/book/query'
import type { UserId } from '~/domain/shared/types'
import { isHeld, MAX_WISHES, newestFirst, wishIdOf } from '~/domain/wish/business-rules'
import { WishCommand } from '~/domain/wish/command'
import { WishQuery } from '~/domain/wish/query'
import type { Wish, WishedBook, WishId, WishOrigin } from '~/domain/wish/types'

export type WishOutcome = Wish | 'in-library' | 'too-many'

export namespace WishUseCase {
  /** Wish for a book the reader came across — a friend's, a discovery, a
   *  scan. Wishing for it twice answers the first wish, from wherever it came.
   *  A story the library holds already is not wished for. */
  export const wish = async (
    userId: UserId,
    book: WishedBook,
    origin: WishOrigin,
    now = new Date(),
  ): Promise<WishOutcome> => {
    const [shelfKeys, all] = await Promise.all([
      BookQuery.shelfKeys(userId),
      WishQuery.byUser(userId),
    ])
    if (isHeld(book, shelfKeys)) return 'in-library'
    const id = wishIdOf(userId, book)
    const known = all.find((wish) => wish.id === id)
    if (known) return known
    if (all.length >= MAX_WISHES) return 'too-many'
    return WishCommand.save({ ...book, id, userId, origin, wishedAt: now })
  }

  /** Drop a wish. False when the reader has none by that id. */
  export const remove = async (userId: UserId, id: WishId): Promise<boolean> => {
    const all = await WishQuery.byUser(userId)
    if (!all.some((wish) => wish.id === id)) return false
    await WishCommand.remove(userId, [id])
    return true
  }

  /** Every wish, the latest first. The ones whose story the library now holds
   *  — scanned, synced from Kindle or Audible, added by hand or from a friend —
   *  are no longer wished for, and go. */
  export const wishes = async (userId: UserId): Promise<Wish[]> => {
    const all = await WishQuery.byUser(userId)
    if (all.length === 0) return []
    const shelfKeys = await BookQuery.shelfKeys(userId)
    const held = all.filter((wish) => isHeld(wish, shelfKeys))
    if (held.length > 0)
      await WishCommand.remove(
        userId,
        held.map((wish) => wish.id),
      )
    return newestFirst(all.filter((wish) => !held.includes(wish)))
  }
}
