import { chunk } from 'lodash-es'
import { sameAuthor } from '~/domain/book/business-rules'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

const SEPARATOR = ' — '

/** A book's title without the author the app named beside it, when it ends
 *  with one of the book's own authors: "La Horde du Contrevent — Alain
 *  Damasio" by Alain Damasio is "La Horde du Contrevent". */
const bookUpdate = (data: FirebaseFirestore.DocumentData) => {
  if (typeof data.title !== 'string' || !Array.isArray(data.authors)) return undefined
  const at = data.title.lastIndexOf(SEPARATOR)
  if (at <= 0) return undefined
  const named = data.title.slice(at + SEPARATOR.length)
  const byItsAuthor = data.authors.some(
    (author: unknown) => typeof author === 'string' && sameAuthor(named, author),
  )
  return byItsAuthor ? { title: data.title.slice(0, at).trim() } : undefined
}

/** Every book titled without its author.
 *
 *  A title looked up after picking a candidate, or added from a saga or an
 *  author page, was asked as "title — author", and the model kept the whole
 *  string as the title. The lookup now asks for the title and the author apart;
 *  what it wrote before is rewritten, so a shelf photo recognises those books
 *  as already kept.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const titlesWithoutTheirAuthor: Migration = {
  version: MigrationVersion(25),
  name: MigrationName('titles-without-their-author'),
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
