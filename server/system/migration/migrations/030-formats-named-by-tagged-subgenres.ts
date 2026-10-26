import { chunk } from 'lodash-es'
import { formatSettledBySubgenres } from '~/domain/book/business-rules'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

/** A stored subgenre's label: a `{ label, language }` tag since subgenres were
 *  tagged with their language, a bare string before. */
const labelOf = (subgenre: unknown): string | undefined => {
  if (typeof subgenre === 'string') return subgenre
  const label = (subgenre as { label?: unknown } | null)?.label
  return typeof label === 'string' ? label : undefined
}

/** A printed book whose subgenres name a format: "Bande Dessinée" moves from
 *  the subgenres to the format, the other tags kept as they are stored. */
const bookUpdate = (data: FirebaseFirestore.DocumentData) => {
  const { format, subgenres } = data
  if ((format !== undefined && format !== 'book') || !Array.isArray(subgenres)) return undefined
  const labels = subgenres.map(labelOf).filter((label): label is string => label !== undefined)
  const settled = formatSettledBySubgenres(format, labels)
  if (settled.format === format) return undefined
  const kept = new Set(settled.subgenres)
  return {
    format: settled.format,
    subgenres: subgenres.filter((subgenre) => {
      const label = labelOf(subgenre)
      return label === undefined || kept.has(label)
    }),
  }
}

/** Migration 28 done again, on subgenres as they are stored.
 *
 *  It read each subgenre as a string, while a book's subgenres have been
 *  `{ label, language }` tags since September: it matched none, and every
 *  album a scan had saved as a printed book — a whole Universal War One among
 *  them — stayed under "Livres" in the Library tab. This one reads the tag's
 *  label, and the bare strings too.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const formatsNamedByTaggedSubgenres: Migration = {
  version: MigrationVersion(30),
  name: MigrationName('formats-named-by-tagged-subgenres'),
  migrate: async ({ db }) => {
    const updates = (await db.collection('books').get()).docs.flatMap((doc) => {
      const data = bookUpdate(doc.data())
      return data ? [{ ref: doc.ref, data }] : []
    })

    for (const slice of chunk(updates, BATCH_SIZE)) {
      const batch = db.batch()
      for (const { ref, data } of slice) batch.update(ref, data)
      await batch.commit()
    }
    return { ok: true, transformed: updates.length }
  },
}
