import { chunk } from 'lodash-es'
import { formatSettledBySubgenres } from '~/domain/book/business-rules'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

/** A printed book whose subgenres name a format: "Bande Dessinée" moves from
 *  the subgenres to the format. */
const bookUpdate = (data: FirebaseFirestore.DocumentData) => {
  const { format, subgenres } = data
  if ((format !== undefined && format !== 'book') || !Array.isArray(subgenres)) return undefined
  const named = subgenres.filter((subgenre): subgenre is string => typeof subgenre === 'string')
  const settled = formatSettledBySubgenres(format, named)
  if (settled.format === format) return undefined
  return { format: settled.format, subgenres: settled.subgenres }
}

/** Every book a scan filed under a comic's format kept as that format.
 *
 *  A cover the model could not settle was saved as a printed book, while the
 *  web search behind it filed the album under "Bande Dessinée", "Manga" or
 *  "Comics" among its subgenres: the page read "Format: Livre" over a BD. The
 *  scan now lets that subgenre settle the format; what was saved before is
 *  corrected the same way. The saga key does not move, since only a recording
 *  keys its saga apart.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const formatsNamedBySubgenres: Migration = {
  version: MigrationVersion(28),
  name: MigrationName('formats-named-by-subgenres'),
  migrate: async ({ db }) => {
    const updates = (await db.collection('books').get()).docs.flatMap((doc) => {
      const data = bookUpdate(doc.data())
      return data ? [{ ref: doc.ref, data }] : []
    })

    for (const slice of chunk(updates, BATCH_SIZE)) {
      const batch = db.batch()
      for (const { ref, data } of slice) batch.update(ref, data)
      await batch.commit()
    }
    return { ok: true, transformed: updates.length }
  },
}
