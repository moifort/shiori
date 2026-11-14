import { chunk } from 'lodash-es'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'
import { slugify } from '~/utils/slug'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

type Named = { userId?: unknown; title?: unknown; authors?: unknown }

/** `shelfKeyOf` as it stood when this ran: the story's title and first author. */
const shelfKeyOf = ({ title, authors }: Named) =>
  `${slugify(typeof title === 'string' ? title : '')}--${slugify(
    Array.isArray(authors) && typeof authors[0] === 'string' ? authors[0] : '',
  )}`

/** The wishes whose story the reader's library already holds, deleted once.
 *
 *  Until now the wishlist deleted them while it was read; a book's arrival
 *  deletes its wish from now on. A wish held before that, and never read
 *  since, would otherwise stay hidden, and come back if the book left the
 *  library. One query per reader who wishes for anything.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const heldWishesForgotten: Migration = {
  version: MigrationVersion(38),
  name: MigrationName('held-wishes-forgotten'),
  migrate: async ({ db }) => {
    const wishes = await db.collection('wishes').get()
    const byReader = Map.groupBy(wishes.docs, (doc) => (doc.data() as Named).userId)
    const held: FirebaseFirestore.QueryDocumentSnapshot[] = []
    for (const [userId, theirs] of byReader) {
      if (typeof userId !== 'string') continue
      const books = await db.collection('books').where('userId', '==', userId).get()
      const shelf = new Set(books.docs.map((doc) => shelfKeyOf(doc.data() as Named)))
      held.push(...theirs.filter((wish) => shelf.has(shelfKeyOf(wish.data() as Named))))
    }
    for (const slice of chunk(held, BATCH_SIZE)) {
      const batch = db.batch()
      for (const wish of slice) batch.delete(wish.ref)
      await batch.commit()
    }
    return { ok: true, transformed: held.length }
  },
}
