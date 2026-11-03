import { shelfKeyOf } from '~/domain/book/business-rules'
import type { UserId } from '~/domain/shared/types'
import { WishId } from './primitives'
import type { Wish, WishedBook } from './types'

/** A reader wishes for as many books as they like, within reason. */
export const MAX_WISHES = 500

/** One wish per story: the same novel wished from a friend and from Découvrir
 *  is one wish, whatever the format. */
export const wishIdOf = (userId: UserId, book: Pick<WishedBook, 'title' | 'authors'>) =>
  WishId(`${userId}--${shelfKeyOf(book.title, book.authors[0])}`)

/** Whether the library holds the story wished for. */
export const isHeld = (wish: Pick<Wish, 'title' | 'authors'>, shelfKeys: ReadonlySet<string>) =>
  shelfKeys.has(shelfKeyOf(wish.title, wish.authors[0]))

/** The wishes as the list draws them: the latest wished first. */
export const newestFirst = (wishes: readonly Wish[]): Wish[] =>
  [...wishes].sort((a, b) => b.wishedAt.getTime() - a.wishedAt.getTime())
