import { AuthorCommand } from '~/domain/author/command'
import { AuthorKey } from '~/domain/author/primitives'
import { AuthorQuery } from '~/domain/author/query'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

/** The pause between two authors. About 45 faceless authors, a second or so of
 *  lookup each, fit well inside Cloud Run's 180-second request. */
const PAUSE_MS = 1000

/** Migration 31 once more, one author at a time.
 *
 *  It looked four authors up at once, a dozen requests to Wikimedia in the same
 *  instant from a Cloud Run address: Wikidata, Wikipedia and Commons answered
 *  429 to most of them, and Tarek, Trevanian, Jérôme Leroy and four others, whose
 *  faces the lookup does find, were recorded as sought without one. This pass
 *  asks for one author, waits, and asks for the next.
 *
 *  Goes through the domain's own lookup, as migration 31 did: its whole point is
 *  to run that lookup again. */
export const facelessAuthorsSoughtSlowly: Migration = {
  version: MigrationVersion(32),
  name: MigrationName('faceless-authors-sought-slowly'),
  migrate: async ({ db }) => {
    const faceless = (await db.collection('authors').get()).docs
      .filter((doc) => !doc.data().portraitUrl)
      .map((doc) => AuthorKey(doc.ref.id))
    let found = 0
    for (const [index, key] of faceless.entries()) {
      if (index > 0) await new Promise((resolve) => setTimeout(resolve, PAUSE_MS))
      const [author] = await AuthorQuery.byKeys([key])
      if (author && (await AuthorCommand.seekPortrait(author)).portraitUrl) found++
    }
    return { ok: true, transformed: found }
  },
}
