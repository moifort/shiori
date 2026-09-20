import type { StarRating } from '~/domain/book/types'
import type { SeriesId } from '~/domain/series/types'
import * as repository from '~/domain/series-opinion/infrastructure/repository'
import type { SeriesOpinion } from '~/domain/series-opinion/types'
import type { UserId } from '~/domain/shared/types'

export namespace SeriesOpinionCommand {
  /** Rate a saga, or take the rating back by passing undefined.
   *
   *  The saga is not checked to exist. A reader can only rate a saga they are
   *  looking at, which they reached from a volume they own — and an opinion of a
   *  saga the catalogue has never described is still theirs to hold. */
  export const rate = (userId: UserId, seriesId: SeriesId, rating: StarRating | undefined) =>
    write(userId, seriesId, (opinion) => ({ ...opinion, rating }))

  export const setFavorite = (userId: UserId, seriesId: SeriesId, favorite: boolean) =>
    write(userId, seriesId, (opinion) => ({ ...opinion, favorite: favorite || undefined }))

  export const deleteAllForUser = (userId: UserId): Promise<void> =>
    repository.removeAllByUser(userId)
}

// Read, change, and then either store or erase. An opinion holding neither a
// rating nor a heart says exactly what an absent document already says, so it is
// deleted rather than kept as a row that costs a read and answers nothing.
const write = async (
  userId: UserId,
  seriesId: SeriesId,
  change: (opinion: SeriesOpinion) => SeriesOpinion,
): Promise<SeriesOpinion> => {
  const current = (await repository.findBy(userId, seriesId)) ?? { userId, seriesId }
  const next = change(current)
  if (next.rating === undefined && next.favorite === undefined) {
    await repository.remove(userId, seriesId)
    return next
  }
  return repository.save(next)
}
