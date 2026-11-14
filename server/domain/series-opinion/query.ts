import type { SagaKey } from '~/domain/series/types'
import * as repository from '~/domain/series-opinion/infrastructure/repository'
import type { SeriesOpinion } from '~/domain/series-opinion/types'
import type { UserId } from '~/domain/shared/types'

export namespace SeriesOpinionQuery {
  export const of = async (userId: UserId, saga: SagaKey): Promise<SeriesOpinion | undefined> =>
    repository.findBy(userId, saga)

  export const all = async (userId: UserId): Promise<SeriesOpinion[]> =>
    repository.findAllByUser(userId)
}
