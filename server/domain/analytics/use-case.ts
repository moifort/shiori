import type { WriteBatch } from 'firebase-admin/firestore'
import { dashboardOf, localDateOf, VIEW_VERSION } from '~/domain/analytics/business-rules'
import { AnalyticsCommand } from '~/domain/analytics/command'
import { TimeZone } from '~/domain/analytics/primitives'
import { AnalyticsQuery } from '~/domain/analytics/query'
import type {
  AnalyticsView,
  BookCard,
  Dashboard,
  DashboardBook,
  SharedShelf,
  TimeZone as TimeZoneValue,
} from '~/domain/analytics/types'
import { BookQuery } from '~/domain/book/query'
import { cataloguesOf } from '~/domain/series/business-rules'
import { SeriesQuery } from '~/domain/series/query'
import { SeriesOpinionQuery } from '~/domain/series-opinion/query'
import type { UserId } from '~/domain/shared/types'
import { objectStore } from '~/system/object-store'
import { atomically } from '~/utils/firestore'

/** The home dashboard, and the one way a write reaches it.
 *
 *  A write never rebuilds the view: it only flags it stale, in the batch that
 *  carries the write, and the next dashboard read rebuilds it. A rebuild reads
 *  the whole library, so rebuilding on every write made a single star cost the
 *  whole shelf, and made the mutation wait for it — while ten ratings in a row
 *  only ever needed the last rebuild. */
export namespace AnalyticsUseCase {
  /** One document read when the view is fresh; rebuilt first when it is
   *  missing, stale, built by an older rule set, or built in another time zone
   *  than the reader's — so it is never wrong, at worst slow once. */
  export const dashboard = async (
    userId: UserId,
    timeZone: TimeZoneValue,
    now = new Date(),
  ): Promise<Dashboard> => {
    const stored = await AnalyticsQuery.view(userId)
    const view =
      stored && !stored.stale && stored.version === VIEW_VERSION && stored.timeZone === timeZone
        ? stored
        : await rebuild(userId, timeZone, now)
    return withCovers(dashboardOf(view, localDateOf(now, timeZone)))
  }

  /** Run a write the dashboard reflects, with the view's stale flag in the same
   *  batch. `wrote` tells an outcome that changed nothing (a book not found, an
   *  edit refused) from one that did: the former leaves the view alone. */
  export const afterWrite = async <Outcome>(
    userId: UserId,
    write: (batch: WriteBatch) => Promise<Outcome>,
    wrote: (outcome: Outcome) => boolean = () => true,
  ): Promise<Outcome> =>
    atomically(async (batch) => {
      const outcome = await write(batch)
      if (wrote(outcome)) await AnalyticsCommand.markStale(userId, batch)
      return outcome
    })

  /** Run writes too many for one batch — an import, a nightly sync — with the
   *  view flagged stale before the first of them lands, so it can never look
   *  fresh over books it does not count. */
  export const whileStale = async <Outcome>(
    userId: UserId,
    write: () => Promise<Outcome>,
  ): Promise<Outcome> => {
    await AnalyticsCommand.markStale(userId)
    return write()
  }

  /** What each of these readers' friends may see of their shelf, keyed by
   *  reader. One batched read of the views; a view that is missing, stale or
   *  built by an older rule set is rebuilt first, in the time zone it was last
   *  built in, so a friend is never shown a count their last write did not
   *  reach. */
  export const sharedShelves = async (
    userIds: readonly UserId[],
    now = new Date(),
  ): Promise<Map<UserId, SharedShelf>> => {
    const stored = new Map((await AnalyticsQuery.views(userIds)).map((view) => [view.userId, view]))
    const views = await Promise.all(
      [...new Set(userIds)].map(async (userId) => {
        const view = stored.get(userId)
        if (view && !view.stale && view.version === VIEW_VERSION && view.shared) return view
        return rebuild(userId, view?.timeZone ?? FALLBACK_TIME_ZONE, now)
      }),
    )
    return new Map(
      views.flatMap((view) => (view.shared ? [[view.userId, view.shared] as const] : [])),
    )
  }

  /** Flag the view after something it is built from changed outside the
   *  reader's library — a saga they hold gaining its catalogue. */
  export const markStale = (userId: UserId): Promise<void> => AnalyticsCommand.markStale(userId)
}

/** The zone a view is built in when its reader never opened their dashboard:
 *  the counts a friend sees do not depend on it, and the reader's own first
 *  dashboard read rebuilds the view in theirs. */
const FALLBACK_TIME_ZONE = TimeZone('Europe/Paris')

const rebuild = async (
  userId: UserId,
  timeZone: TimeZoneValue,
  now: Date,
): Promise<AnalyticsView> => {
  const [books, opinions] = await Promise.all([
    BookQuery.all(userId),
    SeriesOpinionQuery.all(userId),
  ])
  const seriesIds = [...new Set(books.flatMap((book) => (book.series ? [book.series.id] : [])))]
  // The world's catalogues, and the reader's own count where the world has
  // none: a saga they counted themselves has a bar on the dashboard too.
  const catalogues = [...cataloguesOf(books, await SeriesQuery.byIds(seriesIds), opinions).values()]
  return AnalyticsCommand.rebuild({ userId, books, catalogues, opinions, timeZone, now })
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
