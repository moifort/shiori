import type { WriteBatch } from 'firebase-admin/firestore'
import { analyticsViewOf } from '~/domain/analytics/business-rules'
import * as repository from '~/domain/analytics/infrastructure/repository'
import type { AnalyticsView, TimeZone } from '~/domain/analytics/types'
import type { Book } from '~/domain/book/types'
import type { Series } from '~/domain/series/types'
import type { SeriesOpinion } from '~/domain/series-opinion/types'
import type { UserId } from '~/domain/shared/types'

export namespace AnalyticsCommand {
  /** Build the reader's view from every book they own and every saga they have
   *  an opinion of, and write it whole.
   *
   *  A full rebuild rather than an increment: a view rebuilt from source cannot
   *  drift — a wrong rule is corrected by the next rebuild instead of being baked
   *  in forever. The caller gathers the sources; this only folds and stores. */
  export const rebuild = async (source: {
    userId: UserId
    books: readonly Book[]
    catalogues: readonly Series[]
    opinions: readonly SeriesOpinion[]
    timeZone: TimeZone
    now: Date
  }): Promise<AnalyticsView> => repository.save(analyticsViewOf(source))

  /** Flag the view as behind the library, so the next dashboard read rebuilds
   *  it. Enlisted in the batch of the write it follows when there is one, so the
   *  view can never look fresh while a book it does not reflect is stored. */
  export const markStale = async (userId: UserId, batch?: WriteBatch): Promise<void> =>
    repository.markStale(userId, batch)

  export const deleteForUser = async (userId: UserId): Promise<void> => repository.remove(userId)
}
