import {
  inAuthorOrder,
  matchingAuthorFilter,
  shelvedAuthorsOf,
} from '~/domain/author/business-rules'
import type { ShelvedAuthor } from '~/domain/author/types'
import { BookQuery } from '~/domain/book/query'
import type { Book } from '~/domain/book/types'
import { SeriesOpinionQuery } from '~/domain/series-opinion/query'
import type { UserId } from '~/domain/shared/types'

export namespace AuthorUseCase {
  /** One page of the Authors tab, the authors the reader loves first, narrowed
   *  to those with a heart when `favorite` is set.
   *
   *  Drawn from the books and the opinions alone — one scan each, shared with
   *  the rest of the request — so a page reads no document of its own. */
  export const followedPage = async (
    userId: UserId,
    page: { limit: number; offset: number },
    filter: { favorite?: boolean },
  ): Promise<{ items: ShelvedAuthor<Book>[]; hasMore: boolean }> => {
    const [books, opinions] = await Promise.all([
      BookQuery.all(userId),
      SeriesOpinionQuery.all(userId),
    ])
    const ranked = inAuthorOrder(matchingAuthorFilter(shelvedAuthorsOf(books, opinions), filter))
    return {
      items: ranked.slice(page.offset, page.offset + page.limit),
      hasMore: page.offset + page.limit < ranked.length,
    }
  }
}
