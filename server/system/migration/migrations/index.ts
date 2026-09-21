import { correctAudibleGenres } from '~/system/migration/migrations/001-correct-audible-genres'
import type { Migration } from '~/system/migration/types'

// Forward-only, sequential, no rollback. Adding a new optional field or a new
// collection needs no migration — only renaming, restructuring, or removing
// stale data does, and correcting data a bug wrote.
export const migrations: Migration[] = [correctAudibleGenres]
