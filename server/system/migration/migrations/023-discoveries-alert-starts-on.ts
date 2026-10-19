import { chunk } from 'lodash-es'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

/** Switches the month's discoveries alert on for every reader who already has
 *  settings.
 *
 *  Every alert starts on, but a reader's settings list the alerts switched on
 *  as they stood when they were written: without this, the alert would reach
 *  only the readers who arrive after it. A reader who had switched every alert
 *  off keeps them off — they asked to hear nothing.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const discoveriesAlertStartsOn: Migration = {
  version: MigrationVersion(23),
  name: MigrationName('discoveries-alert-starts-on'),
  migrate: async ({ db }) => {
    const docs = (await db.collection('notification-settings').get()).docs.filter((doc) => {
      const alerts: unknown = doc.data().alerts
      return Array.isArray(alerts) && alerts.length > 0 && !alerts.includes('discoveries')
    })
    for (const slice of chunk(docs, BATCH_SIZE)) {
      const batch = db.batch()
      for (const doc of slice)
        batch.update(doc.ref, { alerts: [...doc.data().alerts, 'discoveries'] })
      await batch.commit()
    }
    return { ok: true, transformed: docs.length }
  },
}
