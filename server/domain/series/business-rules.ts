import type { Series, SeriesState, Volume, VolumeKind } from '~/domain/series/types'
import type { Year } from '~/domain/shared/types'

/** A volume the reader could still be waiting for. Announced volumes are kept in
 *  the catalogue on purpose: they are what a release alert will attach to. */
export const isForthcoming = (volume: Volume, currentYear: Year): boolean =>
  volume.publishedIn !== undefined && volume.publishedIn > currentYear

export const publishedVolumes = (series: Series, currentYear: Year): Volume[] =>
  series.volumes.filter((volume) => !isForthcoming(volume, currentYear))

/** A saga is complete once every volume that exists has been read. Forthcoming
 *  volumes are excluded: a reader who is up to date on a running saga has
 *  finished it as far as the world is concerned, and telling them otherwise
 *  because book 15 is announced for next year would be wrong.
 *
 *  A saga with no published volume at all is `in-progress`, not `complete`:
 *  "complete" would read as an achievement where nothing was achieved. */
export const stateOf = (
  series: Series,
  readVolumeNumbers: ReadonlySet<number>,
  currentYear: Year,
): SeriesState => {
  const published = publishedVolumes(series, currentYear)
  if (published.length === 0) return 'in-progress'
  const everyPublishedRead = published.every(
    (volume) => volume.number !== undefined && readVolumeNumbers.has(volume.number),
  )
  return everyPublishedRead ? 'complete' : 'in-progress'
}

/** Catalogue order for a whole saga. */
export const inCatalogueOrder = (volumes: readonly Volume[]): Volume[] =>
  [...volumes].sort(compareVolumes)

const KIND_RANK: Record<VolumeKind, number> = {
  main: 0,
  prequel: 1,
  'spin-off': 2,
  novella: 3,
  companion: 4,
}

/** The one ordering rule for anything that sits in a saga: the numbered spine
 *  first, ascending, then what orbits it. Shared with the library so a series
 *  section and the series screen never disagree on order — they are the same
 *  saga seen twice.
 *
 *  Titles break the tie between two unnumbered entries. A stable order matters
 *  more than a clever one here: both surfaces are read top to bottom. */
export const compareWithinSeries = (
  left: { kind: VolumeKind; number?: number; title: string },
  right: { kind: VolumeKind; number?: number; title: string },
): number => {
  const byKind = KIND_RANK[left.kind] - KIND_RANK[right.kind]
  if (byKind !== 0) return byKind
  if (left.number !== undefined && right.number !== undefined) return left.number - right.number
  if (left.number !== undefined) return -1
  if (right.number !== undefined) return 1
  return left.title.localeCompare(right.title)
}

const compareVolumes = (left: Volume, right: Volume): number => compareWithinSeries(left, right)

/** Main volumes and everything else, which is how the series screen lays them out:
 *  the spine in order, then a "Related works" block underneath. */
export const splitBySpine = (series: Series): { spine: Volume[]; relatedWorks: Volume[] } => {
  const ordered = inCatalogueOrder(series.volumes)
  return {
    spine: ordered.filter((volume) => volume.kind === 'main'),
    relatedWorks: ordered.filter((volume) => volume.kind !== 'main'),
  }
}
