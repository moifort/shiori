import { AudibleQuery } from '~/domain/audible/query'
import { AudibleUseCase } from '~/domain/audible/use-case'
import { createLogger } from '~/system/logger'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

const log = createLogger('migration')

/** Re-reads every connected reader's Audible library and corrects the genres the
 *  first mapping got wrong: the catch-all literary rack winning because Amazon
 *  listed it first, and whole subtrees left unmapped. See
 *  `genreCorrectionsFor` for which books it may touch.
 *
 *  Not a schema change: nothing stored says what a title's category ladders
 *  were, so the only way back to the right genre is asking Audible again, once.
 *
 *  One reader whose account Amazon refuses is logged and stepped over. Failing
 *  the migration instead would block every later one behind a revoked device. */
export const correctAudibleGenres: Migration = {
  version: MigrationVersion(1),
  name: MigrationName('correct-audible-genres'),
  migrate: async () => {
    let transformed = 0
    for (const userId of await AudibleQuery.connectedReaders()) {
      try {
        const corrected = await AudibleUseCase.correctImportedGenres(userId)
        if (typeof corrected === 'number') transformed += corrected
      } catch (error) {
        log.warn(`genre correction skipped for ${userId}: ${error}`)
      }
    }
    return { ok: true, transformed }
  },
}
