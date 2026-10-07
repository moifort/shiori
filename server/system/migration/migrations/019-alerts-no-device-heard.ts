import { chunk } from 'lodash-es'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

/** Puts back the alerts marked as pushed when no device may have heard them.
 *
 *  Until the fix this follows, the morning alerts, the Sunday digest and the
 *  awaited-edition alerts were marked as pushed whatever became of them: a
 *  reader with no device registered at the time lost them for good. Nothing
 *  recorded which were heard, so every one is put back for the readers who
 *  want that kind: the next pass pushes again what is still within its grace,
 *  and a reader who did hear one may hear it twice. An alert the reader
 *  switched off stays settled — they asked to hear nothing of it.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const alertsNoDeviceHeard: Migration = {
  version: MigrationVersion(19),
  name: MigrationName('alerts-no-device-heard'),
  migrate: async ({ db }) => {
    const settings = new Map(
      (await db.collection('notification-settings').get()).docs.map((doc) => {
        const { userId, alerts } = doc.data()
        return [String(userId), Array.isArray(alerts) ? (alerts as string[]) : []]
      }),
    )
    // A reader with no settings never switched anything off: every alert starts on.
    const wants = (userId: string, kind: string) => settings.get(userId)?.includes(kind) ?? true

    const readers = (await db.collection('discovery-readers').get()).docs.flatMap((doc) => {
      const data = doc.data()
      const notified: unknown[] = Array.isArray(data.notified) ? data.notified : []
      const announced: unknown[] = Array.isArray(data.announced) ? data.announced : []
      const fields: Record<string, unknown[]> = {}
      if (notified.length > 0 && wants(String(data.userId), 'translation')) fields.notified = []
      if (announced.length > 0 && wants(String(data.userId), 'digest')) fields.announced = []
      return Object.keys(fields).length > 0 ? [{ ref: doc.ref, fields }] : []
    })
    const editions = (await db.collection('awaited-editions').get()).docs.flatMap((doc) => {
      const { notifiedAt, ...data } = doc.data()
      return notifiedAt !== undefined && wants(String(data.userId), 'translation')
        ? [{ ref: doc.ref, data }]
        : []
    })

    for (const slice of chunk(readers, BATCH_SIZE)) {
      const batch = db.batch()
      for (const { ref, fields } of slice) batch.update(ref, fields)
      await batch.commit()
    }
    for (const slice of chunk(editions, BATCH_SIZE)) {
      const batch = db.batch()
      for (const { ref, data } of slice) batch.set(ref, data)
      await batch.commit()
    }
    return { ok: true, transformed: readers.length + editions.length }
  },
}
