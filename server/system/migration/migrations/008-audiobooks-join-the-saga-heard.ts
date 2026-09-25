import type { WriteBatch } from 'firebase-admin/firestore'
import { chunk } from 'lodash-es'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

const AUDIO_SUFFIX = '--audio'

/** Moves every audiobook in a saga to the saga heard, keyed `{saga}--audio`.
 *
 *  A recording trails its printed book, sometimes by years, and some are never
 *  made: a listener measured against the printed spine saw volumes they could
 *  not listen to offered as missing. The saga heard is now a saga of its own,
 *  and the audiobooks filed before it existed join it.
 *
 *  A reader's opinion of the saga follows their volumes: moved when they only
 *  listened to it, copied to both sagas when they read and listened to it.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const audiobooksJoinTheSagaHeard: Migration = {
  version: MigrationVersion(8),
  name: MigrationName('audiobooks-join-the-saga-heard'),
  migrate: async ({ db }) => {
    const books = (await db.collection('books').get()).docs
    const moved = books.filter((doc) => {
      const book = doc.data()
      return (
        book.format === 'audiobook' &&
        typeof book.series?.id === 'string' &&
        !book.series.id.endsWith(AUDIO_SUFFIX)
      )
    })

    // Per reader and saga: whether they hold volumes that stay in the saga read.
    const heard = new Set(moved.map((doc) => `${doc.data().userId}--${doc.data().series.id}`))
    const stillRead = new Set(
      books.flatMap((doc) => {
        const book = doc.data()
        return book.format !== 'audiobook' && typeof book.series?.id === 'string'
          ? [`${book.userId}--${book.series.id}`]
          : []
      }),
    )
    const opinions = (await db.collection('series-opinions').get()).docs.filter((doc) =>
      heard.has(`${doc.data().userId}--${doc.data().seriesId}`),
    )

    const writes = [
      ...moved.map((doc) => (batch: WriteBatch) => {
        const series = doc.data().series
        batch.update(doc.ref, { series: { ...series, id: `${series.id}${AUDIO_SUFFIX}` } })
      }),
      ...opinions.map((doc) => (batch: WriteBatch) => {
        const opinion = doc.data()
        const seriesId = `${opinion.seriesId}${AUDIO_SUFFIX}`
        batch.set(db.collection('series-opinions').doc(`${opinion.userId}--${seriesId}`), {
          ...opinion,
          seriesId,
        })
        if (!stillRead.has(`${opinion.userId}--${opinion.seriesId}`)) batch.delete(doc.ref)
      }),
    ]
    // Two operations at most per write, well inside a batch.
    for (const slice of chunk(writes, BATCH_SIZE / 2)) {
      const batch = db.batch()
      for (const write of slice) write(batch)
      await batch.commit()
    }
    return { ok: true, transformed: moved.length }
  },
}
