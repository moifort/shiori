import { BookQuery } from '~/domain/book/query'
import type { ReleaseView } from '~/domain/release/types'
import { type DescribeRefusal, ReleaseUseCase } from '~/domain/release/use-case'
import type { Language } from '~/domain/shared/language'
import type { UserId } from '~/domain/shared/types'
import {
  isHeld,
  MAX_WISHES,
  newestFirst,
  releaseIdentityOf,
  releaseShownOf,
  wishIdOf,
} from '~/domain/wish/business-rules'
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

  /** Every wish, the latest first. A story the library now holds is no
   *  longer wished for: the book's arrival deleted its wish
   *  (`WishCommand.forgetHeld`), and one the library held before that rule is
   *  left out here all the same. */
  export const wishes = async (userId: UserId): Promise<Wish[]> => {
    const all = await WishQuery.byUser(userId)
    if (all.length === 0) return []
    const shelfKeys = await BookQuery.shelfKeys(userId)
    return newestFirst(all.filter((wish) => !isHeld(wish, shelfKeys)))
  }

  /** Describe a wish for its page, as a discovery is: the shared release of
   *  its edition, paid once for every reader. Not found for a wish the
   *  reader does not have. */
  export const describe = async (
    userId: UserId,
    id: WishId,
    appLanguage: Language,
    now = new Date(),
  ): Promise<ReleaseView | DescribeRefusal | 'not-found'> => {
    const wish = (await WishQuery.byUser(userId)).find((candidate) => candidate.id === id)
    if (!wish) return 'not-found'
    return ReleaseUseCase.describeShown(
      userId,
      releaseIdentityOf(wish, appLanguage),
      releaseShownOf(wish, appLanguage),
      appLanguage,
      now,
    )
  }
}
