import type { Firestore } from 'firebase-admin/firestore'
import type { Brand } from 'ts-brand'

export type MigrationVersion = Brand<number, 'MigrationVersion'>
export type MigrationName = Brand<string, 'MigrationName'>

export type MigrationContext = { db: Firestore }

export type Migration = {
  version: MigrationVersion
  name: MigrationName
  migrate: (ctx: MigrationContext) => Promise<MigrationResult>
}

export type MigrationMeta = { version: MigrationVersion; appliedAt: Date }
export type MigrationResult = { ok: true; transformed: number } | { ok: false; error: string }
