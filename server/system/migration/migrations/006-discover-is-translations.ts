import { chunk } from 'lodash-es'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

/** The collections the old Découvrir tab kept: its per-reader shelves, and the
 *  shared release watches and genre lists behind them. The tab now only looks
 *  for translations, in documents of another shape, rebuilt by the next
 *  refresh. */
const RETIRED = ['discover', 'release-watches', 'genre-lists']

/** Découvrir became the translations of what the reader read in another
 *  language. Its stored shelves go, and the notification settings keep the one
 *  alert left — switched on for everybody, since it now starts on — dropping
 *  the saga, author and Audible alerts that no longer exist.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const discoverIsTranslations: Migration = {
  version: MigrationVersion(6),
  name: MigrationName('discover-is-translations'),
  migrate: async ({ db }) => {
    const retired = (
      await Promise.all(RETIRED.map((collection) => db.collection(collection).get()))
    ).flatMap((snapshot) => snapshot.docs.map((doc) => doc.ref))
    for (const slice of chunk(retired, BATCH_SIZE)) {
      const batch = db.batch()
      for (const ref of slice) batch.delete(ref)
      await batch.commit()
    }

    const settings = await db.collection('notification-settings').get()
    for (const slice of chunk(settings.docs, BATCH_SIZE)) {
      const batch = db.batch()
      for (const doc of slice) batch.update(doc.ref, { alerts: ['translation'] })
      await batch.commit()
    }
    return { ok: true, transformed: retired.length + settings.docs.length }
  },
}
