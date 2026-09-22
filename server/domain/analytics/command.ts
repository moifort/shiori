import type { WriteBatch } from 'firebase-admin/firestore'
import { analyticsViewOf } from '~/domain/analytics/business-rules'
import * as repository from '~/domain/analytics/infrastructure/repository'
import { TimeZone } from '~/domain/analytics/primitives'
import type { AnalyticsView, TimeZone as TimeZoneValue } from '~/domain/analytics/types'
import { BookQuery } from '~/domain/book/query'
import { cataloguesOf } from '~/domain/series/business-rules'
import { SeriesQuery } from '~/domain/series/query'
import type { SeriesId } from '~/domain/series/types'
import { SeriesOpinionQuery } from '~/domain/series-opinion/query'
import type { UserId } from '~/domain/shared/types'

/** The zone a view is built in before the app has ever read its dashboard. The
 *  first read in the reader's own zone rebuilds it. */
const DEFAULT_TIME_ZONE = TimeZone('UTC')

export namespace AnalyticsCommand {
  /** Rebuild the reader's view from every book they own and every saga they
   *  have an opinion of, and write it whole.
   *
   *  A full rebuild rather than an increment: writes are rare next to dashboard
   *  reads, and a view rebuilt from source cannot drift — a wrong rule is corrected
   *  by the next write instead of being baked in forever. Without a time zone the
   *  view keeps the one it was last built in. */
  export const refresh = async (
    userId: UserId,
    timeZone?: TimeZoneValue,
    now = new Date(),
  ): Promise<AnalyticsView> => {
    const zone = timeZone ?? (await repository.findByUser(userId))?.timeZone ?? DEFAULT_TIME_ZONE
    const books = await BookQuery.all(userId)
    const seriesIds = [...new Set(books.flatMap((book) => (book.series ? [book.series.id] : [])))]
    const opinions = await SeriesOpinionQuery.all(userId)
    // The world's catalogues, and the reader's own count where the world has
    // none: a saga they counted themselves has a bar on the dashboard too.
    const catalogues = [
      ...cataloguesOf(books, await SeriesQuery.byIds(seriesIds as SeriesId[]), opinions).values(),
    ]
    return repository.save(
      analyticsViewOf({ userId, books, catalogues, opinions, timeZone: zone, now }),
    )
  }

  /** Enlisted in the batch of a book write, so the view can never look fresh
   *  while a book it does not reflect is already stored. */
  export const markStale = (userId: UserId, batch: WriteBatch): void =>
    repository.markStale(userId, batch)

  export const deleteForUser = async (userId: UserId): Promise<void> => repository.remove(userId)
}
