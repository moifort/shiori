import {
  featuredSagaOf,
  inAuthorOrder,
  matchingAuthorFilter,
  shelvedAuthorsOf,
} from '~/domain/author/business-rules'
import type { FollowedAuthor } from '~/domain/author/types'
import { BookQuery } from '~/domain/book/query'
import type { Book } from '~/domain/book/types'
import { SeriesUseCase } from '~/domain/series/use-case'
import { SeriesOpinionQuery } from '~/domain/series-opinion/query'
import type { UserId } from '~/domain/shared/types'

export namespace AuthorUseCase {
  /** One page of the Authors tab, the authors the reader loves first, narrowed
   *  to those with a heart when `favorite` is set.
   *
   *  Which authors a page holds depends on the books and the opinions alone —
   *  one scan each, shared with the rest of the request — so only the sagas of
   *  the page's authors have their catalogue read, in one getAll. */
  export const followedPage = async (
    userId: UserId,
    page: { limit: number; offset: number },
    filter: { favorite?: boolean },
  ): Promise<{ items: FollowedAuthor<Book>[]; hasMore: boolean }> => {
    const [books, opinions] = await Promise.all([
      BookQuery.all(userId),
      SeriesOpinionQuery.all(userId),
    ])
    const ranked = inAuthorOrder(matchingAuthorFilter(shelvedAuthorsOf(books, opinions), filter))
    const items = ranked.slice(page.offset, page.offset + page.limit)
    const sagas = await SeriesUseCase.followedAmong(
      userId,
      new Set(items.flatMap((author) => author.seriesIds)),
    )
    return {
      items: items.map((author) => ({
        ...author,
        saga: featuredSagaOf(sagas.filter((saga) => author.seriesIds.includes(saga.id))),
      })),
      hasMore: page.offset + page.limit < ranked.length,
    }
  }
}
