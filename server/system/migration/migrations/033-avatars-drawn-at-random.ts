import { chunk, sample } from 'lodash-es'
import { AVATAR_HEROES } from '~/domain/user/types'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

/** A hero drawn at random for every reader who onboarded before avatars.
 *
 *  A new reader is offered a random hero by the wizard; those already in would
 *  otherwise open the app on bare initials, the look of an account nobody set
 *  up. A profile that already wears an avatar is left alone, so a second run
 *  changes nothing. */
export const avatarsDrawnAtRandom: Migration = {
  version: MigrationVersion(33),
  name: MigrationName('avatars-drawn-at-random'),
  migrate: async ({ db }) => {
    const bare = (await db.collection('users').get()).docs.filter((doc) => !doc.data().avatar)
    for (const docs of chunk(bare, BATCH_SIZE)) {
      const batch = db.batch()
      for (const doc of docs)
        batch.update(doc.ref, { avatar: { kind: 'hero', hero: sample(AVATAR_HEROES) } })
      await batch.commit()
    }
    return { ok: true, transformed: bare.length }
  },
}
