import { chunk, isEqual } from 'lodash-es'
import { titleWithoutAuthor } from '~/domain/book/business-rules'
import { singleSpaced } from '~/domain/shared/primitives'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

const spaced = (value: unknown) => (typeof value === 'string' ? singleSpaced(value) : value)

/** A book's title, authors and saga name written with single spaces, and its
 *  title without one of its authors named beside it: "La  Horde du Contrevent
 *  - Damasio" by Alain Damasio is "La Horde du Contrevent". */
const bookUpdate = (data: FirebaseFirestore.DocumentData) => {
  if (typeof data.title !== 'string' || !Array.isArray(data.authors)) return undefined
  const authors = data.authors.map(spaced)
  const named = authors.filter((author): author is string => typeof author === 'string')
  const title = titleWithoutAuthor(singleSpaced(data.title), named)
  const series =
    data.series && typeof data.series.name === 'string'
      ? { ...data.series, name: singleSpaced(data.series.name) }
      : data.series
  const update = {
    ...(title !== data.title ? { title } : {}),
    ...(!isEqual(authors, data.authors) ? { authors } : {}),
    ...(!isEqual(series, data.series) ? { series } : {}),
  }
  return Object.keys(update).length > 0 ? update : undefined
}

/** Every book titled and credited with single spaces, and titled without its
 *  author.
 *
 *  A title kept the double spaces and line breaks of a spine read or a pasted
 *  listing, and a store's "title - author" or "title (author)" stayed whole
 *  where only the app's own "title — author" was cut (migration 025). Titles and
 *  names are now single-spaced when written, and the author is cut from a new
 *  book's title; what was written before is rewritten the same way.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const titlesSingleSpaced: Migration = {
  version: MigrationVersion(26),
  name: MigrationName('titles-single-spaced'),
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
