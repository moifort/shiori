import type { Migration } from '~/system/migration/types'

// Forward-only, sequential, no rollback. Shiori restarted on an empty database,
// so the list is empty again. Adding a new optional field or a new collection
// needs no migration — only renaming, restructuring, or removing stale data does.
//
// Number the next one 3: `migration-meta` in production already records version 2,
// left there by the two migrations this list held before the reset, and the runner
// skips any version at or below it.
export const migrations: Migration[] = []
