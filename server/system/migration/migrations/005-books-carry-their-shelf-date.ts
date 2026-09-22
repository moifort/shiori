import { chunk } from 'lodash-es'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

/** Stamps every stored book with the date the Library tab shelves it on —
 *  finished, else started, else added — which the tab now pages on with a
 *  Firestore cursor. A query ordered on a field leaves out every document that
 *  lacks it, so a book written before the field existed would vanish from the
 *  tab until it was written again.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const booksCarryTheirShelfDate: Migration = {
  version: MigrationVersion(5),
  name: MigrationName('books-carry-their-shelf-date'),
  migrate: async ({ db }) => {
    const books = await db.collection('books').get()
    const changes = books.docs.flatMap((doc) => {
      const book = doc.data()
      if (book.shelvedAt !== undefined) return []
      const shelvedAt = book.finishedAt ?? book.startedAt ?? book.addedAt
      return shelvedAt === undefined ? [] : [{ ref: doc.ref, shelvedAt }]
    })
    for (const slice of chunk(changes, BATCH_SIZE)) {
      const batch = db.batch()
      for (const { ref, shelvedAt } of slice) batch.update(ref, { shelvedAt })
      await batch.commit()
    }
    return { ok: true, transformed: changes.length }
  },
}
