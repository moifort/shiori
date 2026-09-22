import type { WriteBatch } from 'firebase-admin/firestore'
import { AnalyticsCommand } from '~/domain/analytics/command'
import { AnalyticsUseCase } from '~/domain/analytics/use-case'
import type { StarRating } from '~/domain/book/types'
import type { SeriesId, VolumeNumber } from '~/domain/series/types'
import { SeriesOpinionCommand } from '~/domain/series-opinion/command'
import type { SeriesOpinion } from '~/domain/series-opinion/types'
import type { UserId } from '~/domain/shared/types'
import { atomically } from '~/utils/firestore'

/** What a reader says about a saga, kept in step with the analytics view: the
 *  dashboard counts the hearts, so a heart given or taken back must reach it
 *  the way a book write does. The GraphQL layer writes opinions through here,
 *  never through `SeriesOpinionCommand` directly. */
export namespace SeriesOpinionUseCase {
  export const rate = (userId: UserId, seriesId: SeriesId, rating: StarRating | undefined) =>
    withAnalytics(userId, (batch) => SeriesOpinionCommand.rate(userId, seriesId, rating, batch))

  export const setFavorite = (userId: UserId, seriesId: SeriesId, favorite: boolean) =>
    withAnalytics(userId, (batch) =>
      SeriesOpinionCommand.setFavorite(userId, seriesId, favorite, batch),
    )

  /** The dashboard's progress bars leave out a saga set aside, so following
   *  reaches the view as a heart does. */
  export const setFollowed = (userId: UserId, seriesId: SeriesId, followed: boolean) =>
    withAnalytics(userId, (batch) =>
      SeriesOpinionCommand.setFollowed(userId, seriesId, followed, batch),
    )

  /** The dashboard measures a saga against this count when nobody has
   *  catalogued it, so the count reaches the view as a heart does. */
  export const declareVolumeCount = (
    userId: UserId,
    seriesId: SeriesId,
    volumeCount: VolumeNumber,
  ) =>
    withAnalytics(userId, (batch) =>
      SeriesOpinionCommand.declareVolumeCount(userId, seriesId, volumeCount, batch),
    )
}

// The opinion and the view's stale flag land in one batch, as a book and its
// flag do: the view can never look fresh while a heart it does not count is
// already stored.
const withAnalytics = async (
  userId: UserId,
  write: (batch: WriteBatch) => Promise<SeriesOpinion>,
): Promise<SeriesOpinion> => {
  const opinion = await atomically(async (batch) => {
    const result = await write(batch)
    AnalyticsCommand.markStale(userId, batch)
    return result
  })
  await AnalyticsUseCase.refreshAfterWrite(userId)
  return opinion
}
