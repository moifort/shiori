import * as repository from '~/domain/series/infrastructure/repository'
import type { Series, SeriesEdition, SeriesMiss } from '~/domain/series/types'

export namespace SeriesQuery {
  /** The catalogue of a saga in one edition language. */
  export const byId = async (edition: SeriesEdition): Promise<Series | null> =>
    repository.findById(edition)

  export const byIds = async (editions: readonly SeriesEdition[]): Promise<Series[]> =>
    repository.findManyByIds(editions)

  /** When the catalogue call last found nothing on this saga in that edition. */
  export const lastMiss = async (edition: SeriesEdition): Promise<SeriesMiss | null> =>
    repository.findMiss(edition)
}
