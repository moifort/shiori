import { chunk } from 'lodash-es'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

/** Whether a stored watch lists no volume Audible answered for. */
const holdsNoRecording = (volumes: unknown) =>
  !Array.isArray(volumes) || volumes.every((volume) => !(volume as { asin?: unknown } | null)?.asin)

/** Every English saga an Audible sync asked for in vain asked again.
 *
 *  The sync asked Audible's US store alone for an English recording, and a
 *  library bought on audible.co.uk holds ASINs the US store knows nothing of:
 *  the saga was marked as asked with no volume listed, and the sync never asks
 *  a saga twice. It now asks the UK store after the US one; the mark is
 *  removed from the English watches that hold no recording, so the next syncs
 *  list them.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const englishSagasListedAgain: Migration = {
  version: MigrationVersion(29),
  name: MigrationName('english-sagas-listed-again'),
  migrate: async ({ db }) => {
    const unlisted = (await db.collection('saga-watches').get()).docs.flatMap((doc) => {
      const { audibleListed, ...rest } = doc.data()
      const askedInVain =
        audibleListed === true && rest.language === 'en' && holdsNoRecording(rest.volumes)
      return askedInVain ? [{ ref: doc.ref, data: rest }] : []
    })

    for (const slice of chunk(unlisted, BATCH_SIZE)) {
      const batch = db.batch()
      for (const { ref, data } of slice) batch.set(ref, data)
      await batch.commit()
    }
    return { ok: true, transformed: unlisted.length }
  },
}
