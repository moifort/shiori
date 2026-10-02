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

/** A volume as the French catalogue holds it: titled as that edition titles
 *  it, with only that edition's date and cover. */
const inFrench = (volume: RawVolume): RawVolume => {
  const { releases, titles, covers, ...rest } = volume
  const date = releases?.fr
  const cover = covers?.fr
  return {
    ...rest,
    title: titles?.fr ?? volume.title,
    ...(date !== undefined ? { releases: { fr: date } } : {}),
    ...(cover !== undefined ? { covers: { fr: cover } } : {}),
  }
}

/** The catalogue of the volumes that named no language becomes the French one.
 *
 *  Those volumes are French now (migration 15), so the bare `series/{id}`
 *  documents are read by nobody: a saga held in French reads `{id}~fr`. Where
 *  a reader holds the saga in French and it has no French catalogue yet, the
 *  bare one — written in the reader's language, French — is kept as it, so the
 *  saga is not asked of the model again. Every bare catalogue then goes, and
 *  so does every bare record of a catalogue call that found nothing.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const cataloguesWithoutALanguageAreFrench: Migration = {
  version: MigrationVersion(16),
  name: MigrationName('catalogues-without-a-language-are-french'),
  migrate: async ({ db }) => {
    const heldInFrench = new Set(
      (await db.collection('books').get()).docs.flatMap((doc) => {
        const { series, language } = doc.data()
        const id = (series as { id?: unknown } | undefined)?.id
        return typeof id === 'string' && language === 'fr' ? [id] : []
      }),
    )

    const catalogues = (await db.collection('series').get()).docs
    const existing = new Set(catalogues.map((doc) => doc.ref.id))
    const bare = catalogues.filter(
      (doc) => !doc.ref.id.includes('~') && doc.data().language === undefined,
    )
    const french = bare.filter(
      (doc) => heldInFrench.has(doc.ref.id) && !existing.has(`${doc.ref.id}~fr`),
    )
    const misses = (await db.collection('series-misses').get()).docs.filter(
      (doc) => !doc.ref.id.includes('~') && doc.data().language === undefined,
    )

    for (const slice of chunk(french, BATCH_SIZE)) {
      const batch = db.batch()
      for (const doc of slice) {
        const data = doc.data()
        const volumes = (Array.isArray(data.volumes) ? data.volumes : []) as RawVolume[]
        batch.set(db.collection('series').doc(`${doc.ref.id}~fr`), {
          ...data,
          language: 'fr',
          volumes: volumes.map(inFrench),
        })
      }
      await batch.commit()
    }
    for (const slice of chunk([...bare, ...misses], BATCH_SIZE)) {
      const batch = db.batch()
      for (const doc of slice) batch.delete(doc.ref)
      await batch.commit()
    }
    return { ok: true, transformed: french.length + bare.length + misses.length }
  },
}
