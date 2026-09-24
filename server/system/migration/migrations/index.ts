import { heartsAreFiveStars } from '~/system/migration/migrations/004-hearts-are-five-stars'
import { booksCarryTheirShelfDate } from '~/system/migration/migrations/005-books-carry-their-shelf-date'
import { discoverIsTranslations } from '~/system/migration/migrations/006-discover-is-translations'
import type { Migration } from '~/system/migration/types'

// Forward-only, sequential, no rollback. Adding a new optional field or a new
// collection needs no migration — only renaming, restructuring, or removing
// stale data does.
//
// Numbering resumed at 4 after the database was reset: `migration-meta` in
// production records version 2, or 3, left by the migrations this list held
// before, and the runner skips any version at or below the one recorded.
export const migrations: Migration[] = [
  heartsAreFiveStars,
  booksCarryTheirShelfDate,
  discoverIsTranslations,
]
