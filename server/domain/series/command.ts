import type { BookLanguage } from '~/domain/book/types'
import { type FoundVolume, keepingReleases, withReleases } from '~/domain/series/business-rules'
import * as repository from '~/domain/series/infrastructure/repository'
import type { Series, SeriesId } from '~/domain/series/types'

export namespace SeriesCommand {
  /** Record a saga catalogue, or refresh one already known.
   *
   *  The write replaces the volume list: a catalogue re-fetched because a new
   *  volume was announced must replace the stale list, and the entry is a plain
   *  fact with no reader state to preserve. What the release watch wrote on the
   *  volumes — dates, titles and covers per language — is carried over, since
   *  the model's fresh list knows nothing of it. Nothing here is per user, so
   *  one reader refreshing the catalogue improves it for everyone. */
  export const catalogue = async (entry: Series): Promise<Series> =>
    repository.save(keepingReleases(entry, await repository.findById(entry.id)))

  /** Write what the release watch found of one edition into the saga's
   *  catalogue. A saga nobody catalogued is left alone: the watch is no
   *  catalogue, and the series screen builds one on its first opening. */
  export const recordReleases = async (
    seriesId: SeriesId,
    language: BookLanguage,
    found: readonly FoundVolume[],
  ): Promise<Series | null> => {
    const current = await repository.findById(seriesId)
    if (!current || current.provisional) return current
    const merged = withReleases(current, language, found)
    return merged === current ? current : repository.save(merged)
  }

  /** Whether the catalogue already holds this saga — what decides if the third
   *  Gemini call runs at all. A hit means the scan costs two calls, not three. */
  export const isCatalogued = async (seriesId: SeriesId): Promise<boolean> =>
    (await repository.findById(seriesId)) !== null
}
