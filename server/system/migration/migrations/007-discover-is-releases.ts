import { chunk } from 'lodash-es'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

/** A work key before the release watch named no language, since only the
 *  app's was ever searched: `series--{id}` or `book--{shelfKey}`. */
const workKeyIn = (key: string, language: string) => `${key}--${language}`

/** An edition key, `{work}--{format}--{volume}`, the language slotted in after
 *  the work. The format is one of two words, so the last of them splits it. */
const editionKeyIn = (key: string, language: string) => {
  const at = Math.max(key.lastIndexOf('--book--'), key.lastIndexOf('--audiobook--'))
  return at < 0 ? key : `${key.slice(0, at)}--${language}${key.slice(at)}`
}

/** Découvrir became what is coming next in the sagas the reader follows, in
 *  any language. The shared translation watches go — the release watches that
 *  replace them are keyed and shaped differently, and the next refresh builds
 *  them. Each reader's feed keeps what they said and what they were told:
 *  a work set aside, and an alert already pushed, now name the language they
 *  were about, which was the app's. The dated editions go, rebuilt by the next
 *  refresh with the language they are in.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const discoverIsReleases: Migration = {
  version: MigrationVersion(7),
  name: MigrationName('discover-is-releases'),
  migrate: async ({ db }) => {
    const watches = (await db.collection('translation-watches').get()).docs.map((doc) => doc.ref)
    for (const slice of chunk(watches, BATCH_SIZE)) {
      const batch = db.batch()
      for (const ref of slice) batch.delete(ref)
      await batch.commit()
    }

    const feeds = (await db.collection('discover').get()).docs
    for (const slice of chunk(feeds, BATCH_SIZE)) {
      const batch = db.batch()
      for (const doc of slice) {
        const {
          language = 'en',
          dismissed = [],
          notified = [],
        } = doc.data() as {
          language?: string
          dismissed?: string[]
          notified?: string[]
        }
        batch.update(doc.ref, {
          dismissed: dismissed.map((key) => workKeyIn(key, language)),
          notified: notified.map((key) => editionKeyIn(key, language)),
          dated: [],
        })
      }
      await batch.commit()
    }
    return { ok: true, transformed: watches.length + feeds.length }
  },
}
