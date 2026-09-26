import { chunk } from 'lodash-es'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

/** The collections the first Découvrir kept: each reader's feed, the shared
 *  release watches keyed by work, and the book previews. */
const RETIRED = ['discover', 'release-watches', 'book-previews'] as const

/** Découvrir was rebuilt as its own domain, around sagas alone: one shared
 *  watch per saga and language, and a small record per reader. Nothing of the
 *  old one carries over — the hourly pass rebuilds the watches within the week
 *  — so its collections go. The dates it wrote into the sagas' catalogues stay:
 *  they are still true, and the new watches keep them up to date.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const discoveryReplacesDiscover: Migration = {
  version: MigrationVersion(9),
  name: MigrationName('discovery-replaces-discover'),
  migrate: async ({ db }) => {
    let transformed = 0
    for (const name of RETIRED) {
      const refs = (await db.collection(name).get()).docs.map((doc) => doc.ref)
      for (const slice of chunk(refs, BATCH_SIZE)) {
        const batch = db.batch()
        for (const ref of slice) batch.delete(ref)
        await batch.commit()
      }
      transformed += refs.length
    }
    return { ok: true, transformed }
  },
}
