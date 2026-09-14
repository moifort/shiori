import * as repository from '~/domain/series/infrastructure/repository'
import type { Series, SeriesId } from '~/domain/series/types'

export namespace SeriesCommand {
  /** Record a saga catalogue, or refresh one already known.
   *
   *  The write is unconditional: a catalogue re-fetched because a new volume was
   *  announced must replace the stale list, and the entry is a plain fact with no
   *  reader state to preserve. Nothing here is per user, so one reader refreshing
   *  the catalogue improves it for everyone. */
  export const catalogue = async (entry: Series): Promise<Series> => repository.save(entry)

  /** Whether the catalogue already holds this saga — what decides if the third
   *  Gemini call runs at all. A hit means the scan costs two calls, not three. */
  export const isCatalogued = async (seriesId: SeriesId): Promise<boolean> =>
    (await repository.findById(seriesId)) !== null
}
