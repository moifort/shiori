import { chunk } from 'lodash-es'
import { MAX_SUBGENRES, Subgenre } from '~/domain/book/primitives'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

/** Rewrites every stored subgenre in the title case `Subgenre` now produces,
 *  folding two spellings of one label into one: the autocompletion would
 *  otherwise keep offering "Dark fantasy" beside "Dark Fantasy".
 *
 *  Reads the raw documents rather than going through the book repository: a
 *  migration must not depend on a domain type that may change after it. */
export const titleCaseSubgenres: Migration = {
  version: MigrationVersion(2),
  name: MigrationName('title-case-subgenres'),
  migrate: async ({ db }) => {
    const snapshot = await db.collection('books').get()
    const changed = snapshot.docs.flatMap((doc) => {
      const stored: unknown = doc.data().subgenres
      if (!Array.isArray(stored) || stored.length === 0) return []
      const labels = stored.filter((label): label is string => typeof label === 'string')
      const seen = new Set<string>()
      const normalized = labels.flatMap((label) => {
        const subgenre = String(Subgenre(label))
        const key = subgenre.toLocaleLowerCase('fr')
        if (seen.has(key)) return []
        seen.add(key)
        return [subgenre]
      })
      const next = normalized.slice(0, MAX_SUBGENRES)
      const same = next.length === labels.length && next.every((label, i) => label === labels[i])
      return same ? [] : [{ ref: doc.ref, subgenres: next }]
    })
    for (const slice of chunk(changed, BATCH_SIZE)) {
      const batch = db.batch()
      for (const { ref, subgenres } of slice) batch.update(ref, { subgenres })
      await batch.commit()
    }
    return { ok: true, transformed: changed.length }
  },
}
