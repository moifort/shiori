import type { WriteBatch } from 'firebase-admin/firestore'
import { AnalyticsUseCase } from '~/domain/analytics/use-case'
import { BookCommand, type BookEdit, type NewBook } from '~/domain/book/command'
import type {
  BookId,
  ReadingNote,
  ReadingStatus,
  Recommendation,
  StarRating,
} from '~/domain/book/types'
import { SeriesUseCase } from '~/domain/series/use-case'
import type { UserId } from '~/domain/shared/types'

/** Every change a reader makes to their library, kept in step with the analytics
 *  view behind the home dashboard. The GraphQL layer writes books through here,
 *  never through `BookCommand` directly, so no write can forget the view.
 *
 *  The book and the view's stale flag land in one batch: the view can never look
 *  fresh while a book it does not reflect is already stored. */
export namespace BookUseCase {
  /** The saga is named as its catalogue names it, when it has one. */
  export const add = async (userId: UserId, input: NewBook) => {
    const [named] = await SeriesUseCase.namedAfterCatalogues([input])
    return withAnalytics(userId, (batch) => BookCommand.add(userId, named, undefined, batch))
  }

  export const edit = (userId: UserId, bookId: BookId, edit: BookEdit) =>
    withAnalytics(userId, (batch) => BookCommand.edit(userId, bookId, edit, undefined, batch))

  export const setStatus = (userId: UserId, bookId: BookId, status: ReadingStatus) =>
    withAnalytics(userId, (batch) =>
      BookCommand.setStatus(userId, bookId, status, undefined, batch),
    )

  export const rate = (userId: UserId, bookId: BookId, rating: StarRating) =>
    withAnalytics(userId, (batch) => BookCommand.rate(userId, bookId, rating, undefined, batch))

  export const unrate = (userId: UserId, bookId: BookId) =>
    withAnalytics(userId, (batch) => BookCommand.unrate(userId, bookId, undefined, batch))

  export const annotate = (userId: UserId, bookId: BookId, note: ReadingNote | undefined) =>
    withAnalytics(userId, (batch) => BookCommand.annotate(userId, bookId, note, undefined, batch))

  export const recommend = (
    userId: UserId,
    bookId: BookId,
    recommendation: Recommendation | undefined,
  ) =>
    withAnalytics(userId, (batch) =>
      BookCommand.recommend(userId, bookId, recommendation, undefined, batch),
    )

  export const setFavorite = (userId: UserId, bookId: BookId, favorite: boolean) =>
    withAnalytics(userId, (batch) =>
      BookCommand.setFavorite(userId, bookId, favorite, undefined, batch),
    )

  export const setHidden = (userId: UserId, bookId: BookId, hidden: boolean) =>
    withAnalytics(userId, (batch) =>
      BookCommand.setHidden(userId, bookId, hidden, undefined, batch),
    )

  export const remove = (userId: UserId, bookId: BookId) =>
    withAnalytics(userId, (batch) => BookCommand.remove(userId, bookId, batch))
}

// A book that was not found, or an edit refused, wrote nothing, so the view
// stays as it was.
const withAnalytics = <Outcome>(userId: UserId, write: (batch: WriteBatch) => Promise<Outcome>) =>
  AnalyticsUseCase.afterWrite(userId, write, wrote)

const wrote = (outcome: unknown): boolean => outcome !== 'not-found' && outcome !== 'no-author'
