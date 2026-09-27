import { chunk } from 'lodash-es'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

/** A stored date as Firestore returns it, or as the fake keeps it. */
const timeOf = (value: unknown): number | undefined => {
  if (value instanceof Date) return value.getTime()
  if (value && typeof (value as { toDate?: unknown }).toDate === 'function')
    return (value as { toDate: () => Date }).toDate().getTime()
  return undefined
}

/** Drops every release watch older than its saga's catalogue.
 *
 *  A watch writes the dates it finds into the saga's catalogue, but only into
 *  one that exists: a saga catalogued on its first opening, after its watch
 *  last looked, has none of them, and the Series tab and the dashboard take a
 *  volume announced to the day for one already out. Dropped, the watch is
 *  looked up again on the next look at Découvrir, or by the hourly pass, and
 *  its dates written in.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const watchesOlderThanTheirCatalogue: Migration = {
  version: MigrationVersion(11),
  name: MigrationName('watches-older-than-their-catalogue'),
  migrate: async ({ db }) => {
    const cataloguedAt = new Map(
      (await db.collection('series').get()).docs.flatMap((doc) => {
        const at = timeOf(doc.data().catalogedAt)
        return at === undefined ? [] : [[doc.ref.id, at] as const]
      }),
    )
    const stale = (await db.collection('saga-watches').get()).docs.filter((doc) => {
      const { seriesId, checkedAt } = doc.data()
      const catalogued = typeof seriesId === 'string' ? cataloguedAt.get(seriesId) : undefined
      const checked = timeOf(checkedAt)
      return catalogued !== undefined && checked !== undefined && catalogued > checked
    })

    for (const slice of chunk(stale, BATCH_SIZE)) {
      const batch = db.batch()
      for (const doc of slice) batch.delete(doc.ref)
      await batch.commit()
    }
    return { ok: true, transformed: stale.length }
  },
}
