import { sortBy } from 'lodash-es'
import { db } from '~/system/firebase'
import { createLogger } from '~/system/logger'
import { MigrationVersion } from '~/system/migration/primitives'
import type { Migration, MigrationMeta } from '~/system/migration/types'

const log = createLogger('migration')

const META_COLLECTION = 'migration-meta'
const META_DOC_ID = 'state'

export const runMigrations = async (migrations: Migration[]) => {
  const firestore = db()
  const metaRef = firestore.collection(META_COLLECTION).doc(META_DOC_ID)

  const snap = await metaRef.get()
  const current = (snap.data() as MigrationMeta | undefined) ?? {
    version: MigrationVersion(0),
    appliedAt: new Date(0),
  }
  const fromVersion = current.version

  const pending = sortBy(
    migrations.filter((m) => m.version > fromVersion),
    (m) => m.version,
  )
  if (pending.length === 0) return { outcome: 'up-to-date' as const }

  for (const migration of pending) {
    try {
      const result = await migration.migrate({ db: firestore })
      if (!result.ok)
        return { outcome: 'failed' as const, version: migration.version, error: result.error }
      await metaRef.set({ version: migration.version, appliedAt: new Date() })
      // Only output of the runner: visible in Cloud Logging (CI reads the HTTP
      // response of POST /admin/migrate instead).
      log.info(
        `Applied v${migration.version} "${migration.name}" (${result.transformed} transformed)`,
      )
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error)
      return { outcome: 'failed' as const, version: migration.version, error: message }
    }
  }
  const lastVersion = pending[pending.length - 1].version
  return {
    outcome: 'migrated' as const,
    from: fromVersion,
    to: lastVersion,
    applied: pending.length,
  }
}
