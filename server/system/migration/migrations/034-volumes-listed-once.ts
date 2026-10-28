import { chunk } from 'lodash-es'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'
import { slugify } from '~/utils/slug'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

type Change = { ref: FirebaseFirestore.DocumentReference; fields: Record<string, unknown> }
type RawFound = { number?: unknown; title?: unknown; isbn13?: unknown }
type RawVolume = { number?: unknown; title?: unknown; titles?: Record<string, unknown> }

const folded = (title: unknown) => (typeof title === 'string' ? slugify(title) : undefined)

/** The numbers of a watch's volumes that repeat the title and ISBN of a lower
 *  number, each with the folded title it repeats. */
const repeatsOf = (volumes: readonly RawFound[]): Map<number, string> => {
  const seen = new Set<string>()
  const repeats = new Map<number, string>()
  const numbered = volumes.filter((volume) => typeof volume.number === 'number')
  for (const volume of numbered.sort((left, right) => Number(left.number) - Number(right.number))) {
    const title = folded(volume.title)
    if (typeof volume.isbn13 !== 'string' || !title) continue
    const edition = `${volume.isbn13}~${title}`
    if (seen.has(edition)) repeats.set(Number(volume.number), title)
    seen.add(edition)
  }
  return repeats
}

/** One edition listed once in each saga's watch and catalogue.
 *
 *  The web sometimes listed one book under two numbers — La Pleureuse as both
 *  volume 12 and 13 of Erica Falck et Patrik Hedström, same title and ISBN —
 *  and the watch wrote the phantom volume into the shared catalogue, whose
 *  saga page then showed a thirteenth volume that does not exist. A fresh look
 *  no longer keeps such a repeat; those kept before are dropped here, from the
 *  watch and from its edition's catalogue, where the volume at that number
 *  must bear the same title. A number a reader filed a book at is left alone.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const volumesListedOnce: Migration = {
  version: MigrationVersion(34),
  name: MigrationName('volumes-listed-once'),
  migrate: async ({ db }) => {
    const [watches, catalogues, books] = await Promise.all([
      db.collection('saga-watches').get(),
      db.collection('series').get(),
      db.collection('books').get(),
    ])
    const catalogueDocs = new Map(catalogues.docs.map((doc) => [doc.ref.id, doc]))
    const filed = new Set(
      books.docs.flatMap((doc) => {
        const { series, language } = doc.data()
        if (typeof series?.id !== 'string' || typeof series.volume !== 'number') return []
        return [`${series.id}~${typeof language === 'string' ? language : 'fr'}#${series.volume}`]
      }),
    )
    const changes: Change[] = []
    for (const doc of watches.docs) {
      const watch = doc.data()
      if (!Array.isArray(watch.volumes) || typeof watch.seriesId !== 'string') continue
      const catalogueId = `${watch.seriesId}~${watch.language}`
      const repeats = repeatsOf(watch.volumes as RawFound[])
      for (const number of repeats.keys())
        if (filed.has(`${catalogueId}#${number}`)) repeats.delete(number)
      if (repeats.size === 0) continue
      changes.push({
        ref: doc.ref,
        fields: {
          volumes: (watch.volumes as RawFound[]).filter(
            (volume) => !repeats.has(Number(volume.number)),
          ),
        },
      })
      const catalogue = catalogueDocs.get(catalogueId)
      const volumes = catalogue?.data().volumes
      if (!catalogue || !Array.isArray(volumes)) continue
      const kept = (volumes as RawVolume[]).filter((volume) => {
        const title = repeats.get(Number(volume.number))
        if (title === undefined) return true
        return ![volume.title, volume.titles?.[watch.language]].some((t) => folded(t) === title)
      })
      if (kept.length < volumes.length)
        changes.push({ ref: catalogue.ref, fields: { volumes: kept } })
    }

    for (const slice of chunk(changes, BATCH_SIZE)) {
      const batch = db.batch()
      for (const { ref, fields } of slice) batch.update(ref, fields)
      await batch.commit()
    }
    return { ok: true, transformed: changes.length }
  },
}
