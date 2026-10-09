import { chunk } from 'lodash-es'
import { titleWithoutSaga } from '~/domain/shared/saga-title'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'
import { slugify } from '~/utils/slug'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

type Change = { ref: FirebaseFirestore.DocumentReference; fields: Record<string, unknown> }
type RawVolume = {
  number?: unknown
  title?: unknown
  titles?: Record<string, unknown>
  kind?: unknown
}

const folded = (title: unknown, saga: string) =>
  typeof title === 'string' ? slugify(titleWithoutSaga(title, saga)) : undefined

/** The number the catalogue lists the book's volume at, when its title names
 *  exactly one main volume there and that number is not the book's. A title
 *  held twice, or the saga's own name, tells no volume apart. */
const numberInCatalogue = (
  book: FirebaseFirestore.DocumentData,
  catalogue: FirebaseFirestore.DocumentData,
  language: string,
): number | undefined => {
  const saga = catalogue.name
  if (typeof saga !== 'string' || !Array.isArray(catalogue.volumes)) return undefined
  const slug = folded(book.title, saga)
  if (!slug || slug === slugify(saga)) return undefined
  const titled = (catalogue.volumes as RawVolume[]).filter((volume) =>
    [volume.title, volume.titles?.[language]].some((title) => folded(title, saga) === slug),
  )
  const [only] = titled
  if (titled.length !== 1 || only.kind !== 'main' || typeof only.number !== 'number')
    return undefined
  return only.number === book.series.volume ? undefined : only.number
}

/** Every main volume filed at the number its saga's catalogue gives it.
 *
 *  A saga published in cycles prints its numbering per cycle — Sir Arthur
 *  Benton's "cycle 2, tome 2" is Le Coup de Prague, the saga's volume 5 — and
 *  the scan wrote the cover's number. The book then took the place of the
 *  saga's real volume 2, and its own showed as missing. A book is now filed at
 *  its catalogue's number when added; those added before are filed again here,
 *  matched by title in their edition's catalogue. The readers touched have
 *  their dashboard marked stale, since it counts volumes read.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const volumesNumberedThroughTheirSaga: Migration = {
  version: MigrationVersion(20),
  name: MigrationName('volumes-numbered-through-their-saga'),
  migrate: async ({ db }) => {
    const catalogues = new Map(
      (await db.collection('series').get()).docs.map((doc) => [doc.ref.id, doc.data()]),
    )
    const changes: Change[] = []
    const readers = new Set<string>()
    for (const doc of (await db.collection('books').get()).docs) {
      const book = doc.data()
      if (book.series?.kind !== 'main' || typeof book.series.id !== 'string') continue
      const language = typeof book.language === 'string' ? book.language : 'fr'
      const catalogue = catalogues.get(`${book.series.id}~${language}`)
      const volume = catalogue && numberInCatalogue(book, catalogue, language)
      if (volume === undefined) continue
      changes.push({ ref: doc.ref, fields: { series: { ...book.series, volume } } })
      readers.add(String(book.userId))
    }

    const transformed = changes.length
    for (const userId of readers)
      changes.push({ ref: db.collection('analytics').doc(userId), fields: { userId, stale: true } })
    for (const slice of chunk(changes, BATCH_SIZE)) {
      const batch = db.batch()
      // A merge rather than an update: a reader's dashboard may not exist yet.
      for (const { ref, fields } of slice) batch.set(ref, fields, { merge: true })
      await batch.commit()
    }
    return { ok: true, transformed }
  },
}
