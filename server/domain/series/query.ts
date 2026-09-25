import * as repository from '~/domain/series/infrastructure/repository'
import type { Series, SeriesId, SeriesMiss } from '~/domain/series/types'

export namespace SeriesQuery {
  export const byId = async (seriesId: SeriesId): Promise<Series | null> =>
    repository.findById(seriesId)

  export const byIds = async (seriesIds: readonly SeriesId[]): Promise<Series[]> =>
    repository.findManyByIds(seriesIds)

  /** When the catalogue call last found nothing on this saga, if it did. */
  export const lastMiss = async (seriesId: SeriesId): Promise<SeriesMiss | null> =>
    repository.findMiss(seriesId)
}
