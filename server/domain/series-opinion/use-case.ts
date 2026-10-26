import type { WriteBatch } from 'firebase-admin/firestore'
import { AnalyticsUseCase } from '~/domain/analytics/use-case'
import { BookCommand } from '~/domain/book/command'
import { BookQuery } from '~/domain/book/query'
import type { Book, BookLanguage, StarRating } from '~/domain/book/types'
import type { SagaKey, VolumeNumber } from '~/domain/series/types'
import { volumesRatedByHeart } from '~/domain/series-opinion/business-rules'
import { SeriesOpinionCommand } from '~/domain/series-opinion/command'
import type { SeriesOpinion } from '~/domain/series-opinion/types'
import type { UserId } from '~/domain/shared/types'

/** What a reader says about a saga, kept in step with the analytics view: the
 *  dashboard counts the hearts, so a heart given or taken back must reach it
 *  the way a book write does. The GraphQL layer writes opinions through here,
 *  never through `SeriesOpinionCommand` directly. */
export namespace SeriesOpinionUseCase {
  export const rate = (userId: UserId, seriesId: SagaKey, rating: StarRating | undefined) =>
    withAnalytics(userId, (batch) => SeriesOpinionCommand.rate(userId, seriesId, rating, batch))

  /** A heart given to a saga rates, with the saga's stars, the volumes the
   *  reader finished and left unrated, in the same batch. Taking it back
   *  leaves those stars, as on a book. */
  export const setFavorite = async (userId: UserId, seriesId: SagaKey, favorite: boolean) => {
    const rated = favorite ? volumesRatedByHeart(await BookQuery.bySeries(userId, seriesId)) : []
    return withAnalytics(userId, async (batch) => {
      const opinion = await SeriesOpinionCommand.setFavorite(userId, seriesId, favorite, batch)
      const { rating } = opinion
      if (rating !== undefined)
        for (const volume of rated)
          await BookCommand.rate(userId, volume.id, rating, new Date(), batch)
      return opinion
    })
  }

  /** The dashboard's progress bars leave out an edition set aside, so
   *  following reaches the view as a heart does. The editions the reader holds
   *  are read only when one edition is named: they are what following it keeps
   *  aside of a saga set aside as a whole. */
  export const setFollowed = async (
    userId: UserId,
    seriesId: SagaKey,
    followed: boolean,
    language?: BookLanguage,
  ) => {
    const heldLanguages =
      language === undefined ? [] : heldLanguagesOf(await BookQuery.all(userId), seriesId)
    return withAnalytics(userId, (batch) =>
      SeriesOpinionCommand.setFollowed(userId, seriesId, followed, language, heldLanguages, batch),
    )
  }

  /** The dashboard measures a saga against this count when nobody has
   *  catalogued it, so the count reaches the view as a heart does. */
  export const declareVolumeCount = (
    userId: UserId,
    seriesId: SagaKey,
    volumeCount: VolumeNumber,
  ) =>
    withAnalytics(userId, (batch) =>
      SeriesOpinionCommand.declareVolumeCount(userId, seriesId, volumeCount, batch),
    )
}

// The opinion and the view's stale flag land in one batch, as a book and its
// flag do: the view can never look fresh while a heart it does not count is
// already stored.
const withAnalytics = (
  userId: UserId,
  write: (batch: WriteBatch) => Promise<SeriesOpinion>,
): Promise<SeriesOpinion> => AnalyticsUseCase.afterWrite(userId, write)

const heldLanguagesOf = (books: readonly Book[], seriesId: SagaKey): BookLanguage[] => [
  ...new Set(
    books.flatMap((book) =>
      book.series?.saga === seriesId && book.language !== undefined ? [book.language] : [],
    ),
  ),
]
