import { chunk } from 'lodash-es'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

/** Deletes `award-interests`: the genres somebody looked at, which told the
 *  hourly pass whose award winners to look up on the web. Nothing looks a
 *  winner up any more — a winner is looked up once a reader awaits it — so the
 *  collection is read by nobody. */
export const awardInterestsDropped: Migration = {
  version: MigrationVersion(22),
  name: MigrationName('award-interests-dropped'),
  migrate: async ({ db }) => {
    const docs = (await db.collection('award-interests').get()).docs
    for (const slice of chunk(docs, BATCH_SIZE)) {
      const batch = db.batch()
      for (const doc of slice) batch.delete(doc.ref)
      await batch.commit()
    }
    return { ok: true, transformed: docs.length }
  },
}
