import { dashboardOf, localDateOf } from '~/domain/analytics/business-rules'
import { AnalyticsCommand } from '~/domain/analytics/command'
import { AnalyticsQuery } from '~/domain/analytics/query'
import type { BookCard, Dashboard, DashboardBook, TimeZone } from '~/domain/analytics/types'
import type { UserId } from '~/domain/shared/types'
import { createLogger } from '~/system/logger'
import { objectStore } from '~/system/object-store'

const logger = createLogger('analytics')

export namespace AnalyticsUseCase {
  /** The home dashboard. One document read when the view is fresh; rebuilt first
   *  when it is missing, left stale by a failed refresh, or built in another time
   *  zone than the reader's — so it is never wrong, at worst slow once. */
  export const dashboard = async (
    userId: UserId,
    timeZone: TimeZone,
    now = new Date(),
  ): Promise<Dashboard> => {
    const stored = await AnalyticsQuery.view(userId)
    const view =
      stored && !stored.stale && stored.timeZone === timeZone
        ? stored
        : await AnalyticsCommand.refresh(userId, timeZone, now)
    return withCovers(dashboardOf(view, localDateOf(now, timeZone)))
  }

  /** Rebuild after a book write. A failure is logged and swallowed: the write
   *  itself landed, and the view it left stale is rebuilt on the next read. */
  export const refreshAfterWrite = async (userId: UserId): Promise<void> => {
    try {
      await AnalyticsCommand.refresh(userId)
    } catch (error) {
      logger.warn(`refresh failed for ${userId}, left stale: ${error}`)
    }
  }
}

// Signed here rather than stored: a signed URL expires. A dozen covers at most,
// signed concurrently.
const withCovers = async (dashboard: Dashboard<BookCard>): Promise<Dashboard> => {
  const [reading, suggestions, lastFinished] = await Promise.all([
    Promise.all(dashboard.reading.map(withCover)),
    Promise.all(dashboard.suggestions.map(withCover)),
    dashboard.lastFinished ? withCover(dashboard.lastFinished) : undefined,
  ])
  return { ...dashboard, reading, suggestions, lastFinished }
}

// The reader's own photo wins over the publisher's cover, as on the book itself.
const withCover = async ({
  coverPath,
  publishedCoverUrl,
  ...card
}: BookCard): Promise<DashboardBook> => {
  if (coverPath) return { ...card, coverUrl: await objectStore().downloadUrl(coverPath) }
  return publishedCoverUrl ? { ...card, coverUrl: publishedCoverUrl } : card
}
