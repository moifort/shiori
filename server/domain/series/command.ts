import type { BookLanguage } from '~/domain/book/types'
import {
  type FoundVolume,
  keepingCorrections,
  keepingReleases,
  withBareTitles,
  withCorrection,
  withReleases,
} from '~/domain/series/business-rules'
import * as repository from '~/domain/series/infrastructure/repository'
import { seriesIdOf } from '~/domain/series/primitives'
import type { SagaKey, Series, SeriesCorrection, SeriesEdition } from '~/domain/series/types'

export namespace SeriesCommand {
  /** Record a saga's catalogue in one edition, or refresh one already known.
   *
   *  The write replaces the volume list: a catalogue re-fetched because a new
   *  volume was announced must replace the stale list, and the entry is a plain
   *  fact with no reader state to preserve. What the release watch wrote on the
   *  volumes — dates, titles and covers — is carried over, since the model's
   *  fresh list knows nothing of it. Nothing here is per user, so one reader
   *  refreshing the catalogue improves it for everyone reading that edition.
   *  Its volumes are titled without the saga's name and number, and what a
   *  reader corrected by hand — the name, the description — stays as they
   *  wrote it. */
  export const catalogue = async (entry: Series): Promise<Series> => {
    const previous = await repository.findById(entry)
    return repository.save(
      keepingCorrections(keepingReleases(withBareTitles(entry), previous), previous),
    )
  }

  /** Write a reader's correction into an edition's catalogue, for every reader
   *  of it, the fields it names marked so that no later catalogue call writes
   *  over them. */
  export const correct = (series: Series, correction: SeriesCorrection): Promise<Series> =>
    repository.save(withCorrection(series, correction))

  /** Write what the release watch found of one edition into that edition's
   *  catalogue. An edition nobody catalogued is left alone: the watch is no
   *  catalogue, and the series screen builds one on its first opening. */
  export const recordReleases = async (
    saga: SagaKey,
    language: BookLanguage,
    found: readonly FoundVolume[],
  ): Promise<Series | null> => {
    const current = await repository.findById({ saga, language })
    if (!current || current.provisional) return current
    const merged = withReleases(current, language, found)
    return merged === current ? current : repository.save(merged)
  }

  /** Remember that the catalogue call found no volume of this saga in that
   *  edition, so the next opening answers at once rather than asking again. */
  export const recordNothingFound = (edition: SeriesEdition, at: Date): Promise<void> =>
    repository.saveMiss({
      id: seriesIdOf(edition.saga, edition.language),
      saga: edition.saga,
      ...(edition.language ? { language: edition.language } : {}),
      missedAt: at,
    })

  /** Whether the catalogue already holds this saga in that edition — what
   *  decides if the third Gemini call runs at all. A hit means the scan costs
   *  two calls, not three. */
  export const isCatalogued = async (edition: SeriesEdition): Promise<boolean> =>
    (await repository.findById(edition)) !== null
}
