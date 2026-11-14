import type { WriteBatch } from 'firebase-admin/firestore'
import {
  analyticsViewOf,
  HEARTS_VERSION,
  heartCountOf,
  sharedHeartsOf,
} from '~/domain/analytics/business-rules'
import * as repository from '~/domain/analytics/infrastructure/repository'
import type { AnalyticsView, SharedHearts, TimeZone } from '~/domain/analytics/types'
import type { Book } from '~/domain/book/types'
import type { Series } from '~/domain/series/types'
import type { SeriesOpinion } from '~/domain/series-opinion/types'
import type { UserId } from '~/domain/shared/types'
import { createLogger } from '~/system/logger'

const logger = createLogger('analytics')

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

  /** Build what the reader's friends' feeds need of the shelf from the books
   *  they share and every saga they have an opinion of, and write it whole.
   *  `builtFrom` is the count of flagging writes read before the sources were:
   *  a write landing meanwhile leaves the projection stale, not fresh.
   *
   *  A shelf whose hearts do not fit one document keeps its newest hearts, as
   *  many as fit: the dashboard's news only ever looks a month back, and
   *  Découvrir loses the oldest hearts first. */
  export const rebuildHearts = async (source: {
    userId: UserId
    books: readonly Book[]
    opinions: readonly SeriesOpinion[]
    builtFrom: number
    now: Date
  }): Promise<SharedHearts> => {
    const { userId, books, opinions, builtFrom, now } = source
    const state = { version: HEARTS_VERSION, builtFrom, refreshedAt: now }
    let kept = Number.POSITIVE_INFINITY
    for (;;) {
      const shared = sharedHeartsOf(userId, books, opinions, kept)
      const outcome = await repository.saveHearts(shared, state)
      if (outcome === 'saved') {
        if (shared.truncated)
          logger.info('shared hearts truncated', {
            userId,
            kept,
            of: heartCountOf(books, opinions),
          })
        return shared
      }
      // Shrunk in proportion, with a margin: compressed sizes are not linear.
      const count = Math.min(kept, heartCountOf(books, opinions))
      kept = Math.floor((count / outcome.tooLarge) * 0.9)
    }
  }

  /** Flag the view as behind the library, so the next dashboard read rebuilds
   *  it. Enlisted in the batch of the write it follows when there is one, so the
   *  view can never look fresh while a book it does not reflect is stored. The
   *  projection of the hearts is flagged with it, in the same batch. */
  export const markStale = async (userId: UserId, batch?: WriteBatch): Promise<void> =>
    repository.markStale(userId, batch)

  export const deleteForUser = async (userId: UserId): Promise<void> => repository.remove(userId)
}
