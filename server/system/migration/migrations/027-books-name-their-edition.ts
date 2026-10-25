import { chunk } from 'lodash-es'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

// What a book with no language is written as since migration 015.
const DEFAULT_LANGUAGE = 'fr'

type Write = { ref: FirebaseFirestore.DocumentReference; data: Record<string, unknown> }

/** A book's saga named by its edition: the saga key moves to `series.saga`,
 *  and `series.id` takes the edition's series id, the key then the book's
 *  language after a `~`. A book already named so is left alone. */
const bookWrite = (doc: FirebaseFirestore.QueryDocumentSnapshot): Write | undefined => {
  const { series, language } = doc.data()
  const id = (series as { id?: unknown } | undefined)?.id
  if (typeof id !== 'string' || id.includes('~')) return undefined
  const edition = typeof language === 'string' ? language : DEFAULT_LANGUAGE
  return { ref: doc.ref, data: { series: { ...series, id: `${id}~${edition}`, saga: id } } }
}

/** A catalogue, or a remembered miss, holding its edition's series id in `id`
 *  — its own document id — and the saga key in `saga`. The bare documents of
 *  migration 013, which no book names since 015, keep their id and gain `saga`. */
const editionWrite = (doc: FirebaseFirestore.QueryDocumentSnapshot): Write | undefined => {
  const data = doc.data()
  const at = doc.ref.id.lastIndexOf('~')
  const saga = at < 0 ? doc.ref.id : doc.ref.id.slice(0, at)
  if (data.id === doc.ref.id && data.saga === saga) return undefined
  return { ref: doc.ref, data: { id: doc.ref.id, saga } }
}

/** Every saga named by its edition.
 *
 *  A book named its saga by a key shared across languages and recorded its
 *  language apart, so whoever opened a saga had to carry the pair — and the
 *  home card that forgot opened a page mixing two editions. Each edition is
 *  now a series of its own: the series id `{sagaKey}~{language}`, the id its
 *  catalogue document already had, is written on every book beside the saga
 *  key, and on every catalogue and miss beside theirs.
 *
 *  The reader's opinions stay keyed on the saga, which they are about, and the
 *  release watches stay where they are: re-keying them would ask the web again.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const booksNameTheirEdition: Migration = {
  version: MigrationVersion(27),
  name: MigrationName('books-name-their-edition'),
  migrate: async ({ db }) => {
    const [books, catalogues, misses] = await Promise.all([
      db.collection('books').get(),
      db.collection('series').get(),
      db.collection('series-misses').get(),
    ])
    const writes = [
      ...books.docs.flatMap((doc) => bookWrite(doc) ?? []),
      ...catalogues.docs.flatMap((doc) => editionWrite(doc) ?? []),
      ...misses.docs.flatMap((doc) => editionWrite(doc) ?? []),
    ]

    for (const slice of chunk(writes, BATCH_SIZE)) {
      const batch = db.batch()
      for (const { ref, data } of slice) batch.update(ref, data)
      await batch.commit()
    }
    return { ok: true, transformed: writes.length }
  },
}
