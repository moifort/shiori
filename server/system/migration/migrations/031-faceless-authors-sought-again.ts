import { chunk } from 'lodash-es'
import { AuthorCommand } from '~/domain/author/command'
import { AuthorKey } from '~/domain/author/primitives'
import { AuthorQuery } from '~/domain/author/query'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

/** Authors looked up at once: enough to finish in seconds, few enough that
 *  Wikimedia and Open Library see a reader rather than a crawler. */
const AT_ONCE = 4

/** Every author without a portrait looked up again, now that Wikidata is asked.
 *
 *  On 2026-10-26, 64 of the 279 catalogues had no face. Half had never been
 *  asked again: they were catalogued before 2026-10-02, when a faceless author
 *  only started being looked up again on opening their page, and nobody had
 *  opened it since — the Authors tab drew their initials for good. The other
 *  half were missed by a name-based Wikipedia lookup that Wikidata now
 *  completes: a namesake's page, a disambiguation, or a photo only another
 *  language's page shows.
 *
 *  Goes through the domain's own lookup rather than the raw documents, unlike
 *  other migrations: its whole point is to run that lookup once more. Each
 *  author either gains a portrait or records when it was sought, as opening the
 *  page would. */
export const facelessAuthorsSoughtAgain: Migration = {
  version: MigrationVersion(31),
  name: MigrationName('faceless-authors-sought-again'),
  migrate: async ({ db }) => {
    const faceless = (await db.collection('authors').get()).docs
      .filter((doc) => !doc.data().portraitUrl)
      .map((doc) => AuthorKey(doc.ref.id))
    let found = 0
    for (const keys of chunk(faceless, AT_ONCE)) {
      const authors = await AuthorQuery.byKeys(keys)
      const sought = await Promise.all(authors.map(AuthorCommand.seekPortrait))
      found += sought.filter((author) => author.portraitUrl).length
    }
    return { ok: true, transformed: found }
  },
}
