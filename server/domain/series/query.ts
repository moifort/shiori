import * as repository from '~/domain/series/infrastructure/repository'
import type { Series, SeriesId } from '~/domain/series/types'

export namespace SeriesQuery {
  export const byId = async (seriesId: SeriesId): Promise<Series | null> =>
    repository.findById(seriesId)

  export const byIds = async (seriesIds: readonly SeriesId[]): Promise<Series[]> =>
    repository.findManyByIds(seriesIds)
}
