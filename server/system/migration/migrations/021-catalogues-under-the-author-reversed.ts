import { chunk } from 'lodash-es'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

const AUDIO_SUFFIX = '--audio'

/** The saga keyed with its author's names in the other order, as
 *  `keyWithAuthorReversed` reads it the day this migration was written. */
const reversedOf = (id: string): string | undefined => {
  const heard = id.endsWith(AUDIO_SUFFIX)
  const read = heard ? id.slice(0, -AUDIO_SUFFIX.length) : id
  const [name, author] = read.split('--')
  if (!name || !author) return undefined
  const reversed = author.split('-').reverse().join('-')
  return reversed === author ? undefined : `${name}--${reversed}${heard ? AUDIO_SUFFIX : ''}`
}

/** The catalogues a scan paid for under its author's names in the order the
 *  cover printed them, while the book joined the saga its reader held under
 *  the other — Old Boy by "Garon Tsuchiya" beside Old Boy by "Tsuchiya
 *  Garon". Nobody holds a book under that key and somebody holds the saga
 *  under the other, so the catalogue is read by nobody, and would draw a
 *  second saga for the next reader whose cover prints that order. It goes,
 *  with any record of a catalogue call that found nothing under it. A key held
 *  under neither order is left alone: a catalogue built for a saga offered on
 *  an author's page is held by nobody yet.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const cataloguesUnderTheAuthorReversed: Migration = {
  version: MigrationVersion(21),
  name: MigrationName('catalogues-under-the-author-reversed'),
  migrate: async ({ db }) => {
    const held = new Set(
      (await db.collection('books').get()).docs.flatMap((doc) => {
        const id = (doc.data().series as { id?: unknown } | undefined)?.id
        return typeof id === 'string' ? [id] : []
      }),
    )
    const orphaned = (key: string) => {
      const id = key.split('~')[0] ?? key
      const reversed = reversedOf(id)
      return reversed !== undefined && !held.has(id) && held.has(reversed)
    }
    const stale = [
      ...(await db.collection('series').get()).docs,
      ...(await db.collection('series-misses').get()).docs,
    ].filter((doc) => orphaned(doc.ref.id))

    for (const slice of chunk(stale, BATCH_SIZE)) {
      const batch = db.batch()
      for (const doc of slice) batch.delete(doc.ref)
      await batch.commit()
    }
    return { ok: true, transformed: stale.length }
  },
}
