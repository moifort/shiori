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

/** `numberInCatalogue` as it stands when this runs: the number of the one main
 *  volume the catalogue titles like the book, in the book's language or its
 *  own. A title held twice, or the saga's own name, tells no volume apart. */
const numberInCatalogue = (
  book: FirebaseFirestore.DocumentData,
  catalogue: FirebaseFirestore.DocumentData,
  language: unknown,
): number | undefined => {
  const saga = catalogue.name
  if (typeof saga !== 'string' || !Array.isArray(catalogue.volumes)) return undefined
  const slug = folded(book.title, saga)
  if (!slug || slug === slugify(saga)) return undefined
  const titled = (catalogue.volumes as RawVolume[]).filter((volume) =>
    [volume.title, typeof language === 'string' ? volume.titles?.[language] : undefined].some(
      (title) => folded(title, saga) === slug,
    ),
  )
  const [only] = titled
  if (titled.length !== 1 || only.kind !== 'main' || typeof only.number !== 'number')
    return undefined
  return only.number
}

/** Every main volume held with no number filed at the one its edition's
 *  catalogue lists it at.
 *
 *  A book is numbered from its catalogue when it is added, and migration 20
 *  numbered those shelved before that rule. A saga catalogued after its
 *  volumes were shelved — an import brings a whole library before any of its
 *  sagas is described — left them unnumbered: counted nowhere on the server,
 *  while the app's saga screen placed them by title, so a saga read through
 *  showed finished on its screen and "2 of 3 read" on the home. A catalogue
 *  now numbers them as it is written; those catalogued before are filed here.
 *  Only books without a number are touched. The readers touched have their
 *  dashboard marked stale, since it counts volumes read.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const unnumberedVolumesFiled: Migration = {
  version: MigrationVersion(39),
  name: MigrationName('unnumbered-volumes-filed'),
  migrate: async ({ db }) => {
    const catalogues = new Map(
      (await db.collection('series').get()).docs.map((doc) => [doc.ref.id, doc.data()]),
    )
    const changes: Change[] = []
    const readers = new Set<string>()
    for (const doc of (await db.collection('books').get()).docs) {
      const book = doc.data()
      const series = book.series
      if (series?.kind !== 'main' || series.volume !== undefined) continue
      if (typeof series.id !== 'string') continue
      const catalogue = catalogues.get(series.id)
      const volume = catalogue && numberInCatalogue(book, catalogue, book.language)
      if (volume === undefined) continue
      changes.push({ ref: doc.ref, fields: { series: { ...series, volume } } })
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
