import { chunk } from 'lodash-es'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'
import { slugify } from '~/utils/slug'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

type RawVolume = Record<string, unknown> & {
  title?: unknown
  kind?: unknown
  number?: unknown
  releases?: Record<string, unknown>
  titles?: Record<string, unknown>
  covers?: Record<string, unknown>
}

const titleOf = (volume: RawVolume) => (typeof volume.title === 'string' ? volume.title : '')

const without = (record: Record<string, unknown> | undefined, language: string) => {
  if (!record || !(language in record)) return { record, removed: false }
  const { [language]: _, ...rest } = record
  return { record: Object.keys(rest).length === 0 ? undefined : rest, removed: true }
}

/** The volumes of one catalogue as they stood before the release watch wrote
 *  in another numbering of the saga, or null when it never did.
 *
 *  The watch matched what it found on the number alone, and the web sometimes
 *  numbers a saga another way: Foundation in reading order puts its two
 *  prequels first. Each volume then took its neighbour's title, date and cover
 *  in that language, and the last ones joined the spine a second time. Both
 *  marks are told apart here: a dated main volume whose title an earlier main
 *  volume already carries — once, so a saga whose volumes all bear its name is
 *  left alone — goes; a title written in that language which is the title of
 *  another volume of the catalogue goes, and the date and cover written with
 *  it. The next pass of the watch, matching on titles, writes them back right. */
export const healed = (volumes: readonly RawVolume[], language: string): RawVolume[] | null => {
  const counts = new Map<string, number>()
  for (const volume of volumes)
    counts.set(slugify(titleOf(volume)), (counts.get(slugify(titleOf(volume))) ?? 0) + 1)
  const mains = volumes.filter(
    (volume) => volume.kind === 'main' && typeof volume.number === 'number',
  )
  const repeated = (volume: RawVolume) =>
    volume.kind === 'main' &&
    typeof volume.number === 'number' &&
    volume.releases?.[language] !== undefined &&
    counts.get(slugify(titleOf(volume))) === 2 &&
    mains.some(
      (other) =>
        (other.number as number) < (volume.number as number) &&
        slugify(titleOf(other)) === slugify(titleOf(volume)),
    )
  const kept = volumes.filter((volume) => !repeated(volume))
  let changed = kept.length !== volumes.length
  const result = kept.map((volume) => {
    const written = volume.titles?.[language]
    if (typeof written !== 'string') return volume
    const another = kept.some(
      (other) => other !== volume && slugify(titleOf(other)) === slugify(written),
    )
    if (!another) return volume
    changed = true
    const { titles: _titles, releases: _releases, covers: _covers, ...rest } = volume
    const titles = without(volume.titles, language).record
    const releases = without(volume.releases, language).record
    const covers = without(volume.covers, language).record
    return {
      ...rest,
      ...(titles ? { titles } : {}),
      ...(releases ? { releases } : {}),
      ...(covers ? { covers } : {}),
    }
  })
  return changed ? result : null
}

/** Every catalogue the release watch wrote into under another numbering of
 *  its saga is put back as it stood (`healed`).
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const cataloguesRenumberedByTheWatch: Migration = {
  version: MigrationVersion(17),
  name: MigrationName('catalogues-renumbered-by-the-watch'),
  migrate: async ({ db }) => {
    const repaired = (await db.collection('series').get()).docs.flatMap((doc) => {
      const data = doc.data()
      if (typeof data.language !== 'string' || !Array.isArray(data.volumes)) return []
      const volumes = healed(data.volumes as RawVolume[], data.language)
      return volumes ? [{ ref: doc.ref, volumes }] : []
    })
    for (const slice of chunk(repaired, BATCH_SIZE)) {
      const batch = db.batch()
      for (const { ref, volumes } of slice) batch.update(ref, { volumes })
      await batch.commit()
    }
    return { ok: true, transformed: repaired.length }
  },
}
