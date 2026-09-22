import type { DocumentReference } from 'firebase-admin/firestore'
import { chunk } from 'lodash-es'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

const HEART_RATING = 5

type Change = { ref: DocumentReference; fields: Record<string, unknown> }

/** Gives every stored heart the five stars a heart now stands for, on books and
 *  on saga opinions alike. A favourite book not yet read or dropped is marked
 *  read, as rating it does: its missing reading dates are stamped today, and
 *  the dates the reader already has are kept. The dashboard of every reader
 *  touched is marked stale, since it counts ratings and books read.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const heartsAreFiveStars: Migration = {
  version: MigrationVersion(4),
  name: MigrationName('hearts-are-five-stars'),
  migrate: async ({ db }) => {
    const now = new Date()
    const changes: Change[] = []
    const readers = new Set<string>()

    const books = await db.collection('books').where('favorite', '==', true).get()
    for (const doc of books.docs) {
      const book = doc.data()
      const status = book.status === 'dropped' ? 'dropped' : 'read'
      if (book.rating === HEART_RATING && book.status === status) continue
      const moved = book.status !== status
      changes.push({
        ref: doc.ref,
        fields: {
          rating: HEART_RATING,
          ...(moved && {
            status,
            statusChangedAt: now,
            startedAt: book.startedAt ?? now,
            finishedAt: book.finishedAt ?? now,
          }),
          updatedAt: now,
        },
      })
      readers.add(String(book.userId))
    }

    const opinions = await db.collection('series-opinions').where('favorite', '==', true).get()
    for (const doc of opinions.docs) {
      const opinion = doc.data()
      if (opinion.rating === HEART_RATING) continue
      changes.push({ ref: doc.ref, fields: { rating: HEART_RATING } })
      readers.add(String(opinion.userId))
    }

    const transformed = changes.length
    for (const userId of readers)
      changes.push({ ref: db.collection('analytics').doc(userId), fields: { userId, stale: true } })
    for (const slice of chunk(changes, BATCH_SIZE)) {
      const batch = db.batch()
      // A merge rather than an update: a reader's dashboard may not exist yet.
      for (const { ref, fields } of slice) batch.set(ref, fields, { merge: true })
      await batch.commit()
    }
    return { ok: true, transformed }
  },
}
