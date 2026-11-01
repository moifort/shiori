import { chunk, sample } from 'lodash-es'
import { AVATAR_COLORS } from '~/domain/user/types'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'
import { objectStore } from '~/system/object-store'
import { ObjectPath } from '~/system/object-store/primitives'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

/** Every reader back to the initial of their first name, on a colour drawn at
 *  random: a hero, a photo or no avatar at all gives way, and only initials
 *  already on a colour stay, so a second run changes nothing.
 *
 *  A photo leaves the bucket before its profile lets go of it: a failure half
 *  way is then picked up by the next run, where the other order would strand
 *  the file with nothing left pointing at it. */
export const initialsDrawnAtRandom: Migration = {
  version: MigrationVersion(35),
  name: MigrationName('initials-drawn-at-random'),
  migrate: async ({ db }) => {
    const others = (await db.collection('users').get()).docs.filter(
      (doc) => doc.data().avatar?.kind !== 'initials',
    )
    for (const docs of chunk(others, BATCH_SIZE)) {
      const photos = docs.flatMap((doc) => {
        const avatar = doc.data().avatar
        return avatar?.kind === 'photo' ? [ObjectPath(avatar.path)] : []
      })
      await Promise.all(photos.map((path) => objectStore().remove(path)))
      const batch = db.batch()
      for (const doc of docs)
        batch.update(doc.ref, { avatar: { kind: 'initials', color: sample(AVATAR_COLORS) } })
      await batch.commit()
    }
    return { ok: true, transformed: others.length }
  },
}
