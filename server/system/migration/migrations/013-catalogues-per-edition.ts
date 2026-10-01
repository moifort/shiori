import { chunk } from 'lodash-es'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

type RawVolume = Record<string, unknown> & {
  title?: unknown
  releases?: Record<string, unknown>
  titles?: Record<string, unknown>
  covers?: Record<string, unknown>
}

/** A volume as the catalogue of one language holds it: titled as that edition
 *  titles it, with only that edition's date and cover. */
const volumeIn = (volume: RawVolume, language: string): RawVolume => {
  const { releases, titles, covers, ...rest } = volume
  const date = releases?.[language]
  const cover = covers?.[language]
  return {
    ...rest,
    title: titles?.[language] ?? volume.title,
    ...(date !== undefined ? { releases: { [language]: date } } : {}),
    ...(cover !== undefined ? { covers: { [language]: cover } } : {}),
  }
}

/** Splits each saga's catalogue into one per edition language.
 *
 *  A catalogue was shared by every language: its volume list, the saga's name
 *  and its description came from whoever scanned first, and only the dates,
 *  titles and covers the release watch found were kept per language. Each
 *  edition now has its own document, `{seriesId}~{language}`. One is written
 *  for every language a reader holds the saga in or the watch dated it in,
 *  from the shared one, taking that language's titles, dates and covers — so
 *  no row of the Series tab loses its catalogue. A language already split is
 *  left alone.
 *
 *  The shared document stays where it was: it is now the catalogue of the
 *  volumes that record no language, and harmless where there are none.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const cataloguesPerEdition: Migration = {
  version: MigrationVersion(13),
  name: MigrationName('catalogues-per-edition'),
  migrate: async ({ db }) => {
    const held = new Map<string, Set<string>>()
    for (const doc of (await db.collection('books').get()).docs) {
      const { series, language } = doc.data()
      const id = (series as { id?: unknown } | undefined)?.id
      if (typeof id !== 'string' || typeof language !== 'string') continue
      held.set(id, (held.get(id) ?? new Set()).add(language))
    }

    const catalogues = (await db.collection('series').get()).docs
    const existing = new Set(catalogues.map((doc) => doc.ref.id))
    const writes: { id: string; data: Record<string, unknown> }[] = []
    for (const doc of catalogues) {
      const data = doc.data()
      if (doc.ref.id.includes('~') || data.language !== undefined) continue
      const volumes = (Array.isArray(data.volumes) ? data.volumes : []) as RawVolume[]
      const dated = volumes.flatMap((volume) => Object.keys(volume.releases ?? {}))
      const languages = new Set([...(held.get(doc.ref.id) ?? []), ...dated])
      for (const language of languages) {
        const id = `${doc.ref.id}~${language}`
        if (existing.has(id)) continue
        writes.push({
          id,
          data: {
            ...data,
            language,
            volumes: volumes.map((volume) => volumeIn(volume, language)),
          },
        })
      }
    }

    for (const slice of chunk(writes, BATCH_SIZE)) {
      const batch = db.batch()
      for (const { id, data } of slice) batch.set(db.collection('series').doc(id), data)
      await batch.commit()
    }
    return { ok: true, transformed: writes.length }
  },
}
