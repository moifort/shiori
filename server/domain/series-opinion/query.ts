import type { SeriesId } from '~/domain/series/types'
import * as repository from '~/domain/series-opinion/infrastructure/repository'
import type { SeriesOpinion } from '~/domain/series-opinion/types'
import type { UserId } from '~/domain/shared/types'

export namespace SeriesOpinionQuery {
  export const of = async (userId: UserId, seriesId: SeriesId): Promise<SeriesOpinion | null> =>
    repository.findBy(userId, seriesId)

  export const all = async (userId: UserId): Promise<SeriesOpinion[]> =>
    repository.findAllByUser(userId)
}
