import type { WriteBatch } from 'firebase-admin/firestore'
import { chunk, uniq } from 'lodash-es'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

/** Every book that records no language is French.
 *
 *  A volume without a language was an edition of its own on the Series tab:
 *  a paperback scanned before the scan read the language sat on one row, its
 *  sequel imported from a French Kindle on another, under the same name. A
 *  book is now written in French when nothing names its edition, and the
 *  books stored before say it too. Each reader whose shelf changed has their
 *  dashboard recomputed, since it measures a saga in each edition.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const booksWithoutALanguageAreFrench: Migration = {
  version: MigrationVersion(15),
  name: MigrationName('books-without-a-language-are-french'),
  migrate: async ({ db }) => {
    const unnamed = (await db.collection('books').get()).docs.filter(
      (doc) => typeof doc.data().language !== 'string',
    )

    for (const slice of chunk(unnamed, BATCH_SIZE)) {
      const batch: WriteBatch = db.batch()
      for (const doc of slice) batch.update(doc.ref, { language: 'fr' })
      await batch.commit()
    }

    const readers = uniq(unnamed.map((doc) => doc.data().userId as string))
    for (const slice of chunk(readers, BATCH_SIZE)) {
      const batch: WriteBatch = db.batch()
      for (const userId of slice)
        batch.set(db.collection('analytics').doc(userId), { userId, stale: true }, { merge: true })
      await batch.commit()
    }
    return { ok: true, transformed: unnamed.length }
  },
}
