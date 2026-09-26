import type { WriteBatch } from 'firebase-admin/firestore'
import { chunk } from 'lodash-es'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

/** Names every book's saga as its catalogue does.
 *
 *  A book carries its saga's name, written by whatever filed it: an Audible
 *  import wrote "Red Rising [French Edition]", where the saga screen and the
 *  Series tab show the catalogue's "Red Rising". The Library tab now shows the
 *  same name as the saga, and the books filed before say it too. A saga with no
 *  catalogue keeps the name its books gave it.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const booksCarryTheirSagaName: Migration = {
  version: MigrationVersion(10),
  name: MigrationName('books-carry-their-saga-name'),
  migrate: async ({ db }) => {
    const names = new Map(
      (await db.collection('series').get()).docs.flatMap((doc) => {
        const name = doc.data().name
        return typeof name === 'string' ? [[doc.ref.id, name] as const] : []
      }),
    )
    const renamed = (await db.collection('books').get()).docs.filter((doc) => {
      const series = doc.data().series
      const name = typeof series?.id === 'string' ? names.get(series.id) : undefined
      return name !== undefined && series.name !== name
    })

    for (const slice of chunk(renamed, BATCH_SIZE)) {
      const batch: WriteBatch = db.batch()
      for (const doc of slice) {
        const series = doc.data().series
        batch.update(doc.ref, { series: { ...series, name: names.get(series.id) } })
      }
      await batch.commit()
    }
    return { ok: true, transformed: renamed.length }
  },
}
