import type { Migration } from '~/system/migration/types'

// Forward-only, sequential, no rollback. Shiori starts on an empty database, so
// the list is empty: version 1 will be the first schema change made after data
// exists in production. Adding a new optional field or a new collection needs no
// migration — only renaming, restructuring, or removing stale data does.
export const migrations: Migration[] = []
