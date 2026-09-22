import type { WriteBatch } from 'firebase-admin/firestore'
import { favoriteAfterRating, HEART_RATING } from '~/domain/book/business-rules'
import type { StarRating } from '~/domain/book/types'
import type { SeriesId, VolumeNumber } from '~/domain/series/types'
import * as repository from '~/domain/series-opinion/infrastructure/repository'
import type { SeriesOpinion } from '~/domain/series-opinion/types'
import type { UserId } from '~/domain/shared/types'

export namespace SeriesOpinionCommand {
  /** Rate a saga, or take the rating back by passing undefined.
   *
   *  The saga is not checked to exist. A reader can only rate a saga they are
   *  looking at, which they reached from a volume they own — and an opinion of a
   *  saga the catalogue has never described is still theirs to hold. */
  export const rate = (
    userId: UserId,
    seriesId: SeriesId,
    rating: StarRating | undefined,
    batch?: WriteBatch,
  ) =>
    write(
      userId,
      seriesId,
      (opinion) => ({
        ...opinion,
        rating,
        favorite: favoriteAfterRating(opinion.favorite, rating),
      }),
      batch,
    )

  /** A heart is five stars, as on a book: given with them, taken back with them. */
  export const setFavorite = (
    userId: UserId,
    seriesId: SeriesId,
    favorite: boolean,
    batch?: WriteBatch,
  ) =>
    write(
      userId,
      seriesId,
      (opinion) =>
        favorite
          ? { ...opinion, favorite: true, rating: HEART_RATING }
          : { ...opinion, favorite: undefined, rating: undefined },
      batch,
    )

  /** How many volumes the reader says the saga has. Kept on their opinion,
   *  never on the shared catalogue: a count typed by one reader is not a fact
   *  about the world, and it stops mattering the day the model describes the
   *  saga. */
  export const declareVolumeCount = (
    userId: UserId,
    seriesId: SeriesId,
    volumeCount: VolumeNumber,
    batch?: WriteBatch,
  ) => write(userId, seriesId, (opinion) => ({ ...opinion, volumeCount }), batch)

  /** Set a saga aside, or follow it again. */
  export const setFollowed = (
    userId: UserId,
    seriesId: SeriesId,
    followed: boolean,
    batch?: WriteBatch,
  ) =>
    write(
      userId,
      seriesId,
      (opinion) => ({ ...opinion, unfollowed: followed ? undefined : true }),
      batch,
    )

  /** Forget what the reader made of a saga they no longer hold. */
  export const forget = (userId: UserId, seriesId: SeriesId, batch?: WriteBatch): Promise<void> =>
    repository.remove(userId, seriesId, batch)

  export const deleteAllForUser = (userId: UserId): Promise<void> =>
    repository.removeAllByUser(userId)
}

// Read, change, and then either store or erase. An opinion holding no rating,
// no heart, no count and no unfollowing says exactly what an absent document
// already says, so it is deleted rather than kept as a row that costs a read
// and answers nothing.
const write = async (
  userId: UserId,
  seriesId: SeriesId,
  change: (opinion: SeriesOpinion) => SeriesOpinion,
  batch?: WriteBatch,
): Promise<SeriesOpinion> => {
  const current = (await repository.findBy(userId, seriesId)) ?? { userId, seriesId }
  const next = change(current)
  if (
    next.rating === undefined &&
    next.favorite === undefined &&
    next.volumeCount === undefined &&
    next.unfollowed === undefined
  ) {
    await repository.remove(userId, seriesId, batch)
    return next
  }
  return repository.save(next, batch)
}
