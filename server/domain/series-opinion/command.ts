import type { WriteBatch } from 'firebase-admin/firestore'
import type { BookLanguage } from '~/domain/book/types'
import type { SagaKey, VolumeNumber } from '~/domain/series/types'
import { followingAfter } from '~/domain/series-opinion/business-rules'
import * as repository from '~/domain/series-opinion/infrastructure/repository'
import type { SeriesOpinion } from '~/domain/series-opinion/types'
import { favoriteAfterRating, ratingUnderHeart } from '~/domain/shared/rating'
import type { StarRating, UserId } from '~/domain/shared/types'

export namespace SeriesOpinionCommand {
  /** Rate a saga, or take the rating back by passing undefined.
   *
   *  The saga is not checked to exist. A reader can only rate a saga they are
   *  looking at, which they reached from a volume they own — and an opinion of a
   *  saga the catalogue has never described is still theirs to hold. */
  export const rate = (
    userId: UserId,
    saga: SagaKey,
    rating: StarRating | undefined,
    batch?: WriteBatch,
  ) =>
    write(
      userId,
      saga,
      (opinion) => ({
        ...opinion,
        rating,
        favorite: favoriteAfterRating(opinion.favorite, rating),
        favoritedAt: favoriteAfterRating(opinion.favorite, rating)
          ? opinion.favoritedAt
          : undefined,
      }),
      batch,
    )

  /** A heart sits on three stars or more, as on a book: given on the reader's
   *  own stars when they can hold it, else on five; taken back, it leaves them. */
  export const setFavorite = (
    userId: UserId,
    saga: SagaKey,
    favorite: boolean,
    batch?: WriteBatch,
    now = new Date(),
  ) =>
    write(
      userId,
      saga,
      (opinion) =>
        favorite
          ? {
              ...opinion,
              favorite: true,
              // Hearting it again is not news: the date stays that of the first heart.
              favoritedAt: opinion.favorite === true ? opinion.favoritedAt : now,
              rating: ratingUnderHeart(opinion.rating),
            }
          : { ...opinion, favorite: undefined, favoritedAt: undefined },
      batch,
    )

  /** How many volumes the reader says the saga has. Kept on their opinion,
   *  never on the shared catalogue: a count typed by one reader is not a fact
   *  about the world, and it stops mattering the day the model describes the
   *  saga. */
  export const declareVolumeCount = (
    userId: UserId,
    saga: SagaKey,
    volumeCount: VolumeNumber,
    batch?: WriteBatch,
  ) => write(userId, saga, (opinion) => ({ ...opinion, volumeCount }), batch)

  /** Set a saga aside, or follow it again: one edition when `language` names
   *  it, else the whole saga. `heldLanguages` are the editions the reader
   *  holds, which following one edition of a saga set aside as a whole keeps
   *  aside. */
  export const setFollowed = (
    userId: UserId,
    saga: SagaKey,
    followed: boolean,
    language: BookLanguage | undefined,
    heldLanguages: readonly BookLanguage[],
    batch?: WriteBatch,
  ) =>
    write(
      userId,
      saga,
      (opinion) => ({
        ...opinion,
        ...followingAfter(opinion, followed, language, heldLanguages),
      }),
      batch,
    )

  /** Forget what the reader made of a saga they no longer hold. */
  export const forget = (userId: UserId, saga: SagaKey, batch?: WriteBatch): Promise<void> =>
    repository.remove(userId, saga, batch)

  export const deleteAllForUser = (userId: UserId): Promise<void> =>
    repository.removeAllByUser(userId)
}

// Read, change, and then either store or erase. An opinion holding no rating,
// no heart, no count and nothing set aside says exactly what an absent document
// already says, so it is deleted rather than kept as a row that costs a read
// and answers nothing.
const write = async (
  userId: UserId,
  saga: SagaKey,
  change: (opinion: SeriesOpinion) => SeriesOpinion,
  batch?: WriteBatch,
): Promise<SeriesOpinion> => {
  const current = (await repository.findBy(userId, saga)) ?? { userId, seriesId: saga }
  const next = change(current)
  if (
    next.rating === undefined &&
    next.favorite === undefined &&
    next.volumeCount === undefined &&
    next.unfollowed === undefined &&
    next.unfollowedLanguages === undefined
  ) {
    await repository.remove(userId, saga, batch)
    return next
  }
  return repository.save(next, batch)
}
