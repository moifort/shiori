import type { WriteBatch } from 'firebase-admin/firestore'
import { AnalyticsCommand } from '~/domain/analytics/command'
import { AnalyticsUseCase } from '~/domain/analytics/use-case'
import { BookCommand, type BookEdit, type NewBook } from '~/domain/book/command'
import type { BookId, ReadingNote, ReadingStatus, StarRating } from '~/domain/book/types'
import type { UserId } from '~/domain/shared/types'
import { atomically } from '~/utils/firestore'

/** Every change a reader makes to their library, kept in step with the analytics
 *  view behind the home dashboard. The GraphQL layer writes books through here,
 *  never through `BookCommand` directly, so no write can forget the view.
 *
 *  The book and the view's stale flag land in one batch: the view can never look
 *  fresh while a book it does not reflect is already stored. The rebuild follows
 *  the commit, and a failed one leaves the view stale for the next read to redo. */
export namespace BookUseCase {
  export const add = (userId: UserId, input: NewBook) =>
    withAnalytics(userId, (batch) => BookCommand.add(userId, input, undefined, batch))

  export const edit = (userId: UserId, bookId: BookId, edit: BookEdit) =>
    withAnalytics(userId, (batch) => BookCommand.edit(userId, bookId, edit, batch))

  export const setStatus = (userId: UserId, bookId: BookId, status: ReadingStatus) =>
    withAnalytics(userId, (batch) =>
      BookCommand.setStatus(userId, bookId, status, undefined, batch),
    )

  export const rate = (userId: UserId, bookId: BookId, rating: StarRating) =>
    withAnalytics(userId, (batch) => BookCommand.rate(userId, bookId, rating, undefined, batch))

  export const unrate = (userId: UserId, bookId: BookId) =>
    withAnalytics(userId, (batch) => BookCommand.unrate(userId, bookId, batch))

  export const annotate = (userId: UserId, bookId: BookId, note: ReadingNote | undefined) =>
    withAnalytics(userId, (batch) => BookCommand.annotate(userId, bookId, note, batch))

  export const setHidden = (userId: UserId, bookId: BookId, hidden: boolean) =>
    withAnalytics(userId, (batch) => BookCommand.setHidden(userId, bookId, hidden, batch))

  export const remove = (userId: UserId, bookId: BookId) =>
    withAnalytics(userId, (batch) => BookCommand.remove(userId, bookId, batch))
}

// A book that was not found wrote nothing, so the view stays as it was.
const withAnalytics = async <Outcome>(
  userId: UserId,
  write: (batch: WriteBatch) => Promise<Outcome>,
): Promise<Outcome> => {
  const outcome = await atomically(async (batch) => {
    const result = await write(batch)
    if (result !== 'not-found') AnalyticsCommand.markStale(userId, batch)
    return result
  })
  if (outcome !== 'not-found') await AnalyticsUseCase.refreshAfterWrite(userId)
  return outcome
}
