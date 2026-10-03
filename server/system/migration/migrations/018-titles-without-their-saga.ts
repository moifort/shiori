import { chunk } from 'lodash-es'
import { titleWithoutSaga } from '~/domain/shared/saga-title'
import { MigrationName, MigrationVersion } from '~/system/migration/primitives'
import type { Migration } from '~/system/migration/types'

// Firestore batches accept at most 500 operations.
const BATCH_SIZE = 400

type Update = { ref: FirebaseFirestore.DocumentReference; data: Record<string, unknown> }

const bare = (title: unknown, saga: string) =>
  typeof title === 'string' ? titleWithoutSaga(title, saga) : title

/** A book's title without its saga's name and volume number, when it names
 *  them: "Crescent City, Tome 1 : Maison de la Terre et du Sang" is "Maison de
 *  la Terre et du Sang", filed in Crescent City as volume 1. */
const bookUpdate = (data: FirebaseFirestore.DocumentData) => {
  const saga = data.series?.name
  if (typeof saga !== 'string' || typeof data.title !== 'string') return undefined
  const title = titleWithoutSaga(data.title, saga)
  return title === data.title ? undefined : { title }
}

/** A catalogue's volumes, and their titles in each language, likewise. */
const catalogueUpdate = (data: FirebaseFirestore.DocumentData) => {
  const saga = data.name
  if (typeof saga !== 'string' || !Array.isArray(data.volumes)) return undefined
  const volumes = data.volumes.map((volume: Record<string, unknown>) => {
    const titles = volume.titles as Record<string, unknown> | undefined
    return {
      ...volume,
      title: bare(volume.title, saga),
      ...(titles
        ? {
            titles: Object.fromEntries(
              Object.entries(titles).map(([language, title]) => [language, bare(title, saga)]),
            ),
          }
        : {}),
    }
  })
  return JSON.stringify(volumes) === JSON.stringify(data.volumes) ? undefined : { volumes }
}

/** Every book and every catalogue volume titled without its saga.
 *
 *  The scan, the catalogue call and the release watch wrote titles as stores
 *  list them, saga and number included, where the screens already show both
 *  beside the title. They now write the title alone; what they wrote before is
 *  rewritten the same way.
 *
 *  Reads the raw documents rather than going through the repositories: a
 *  migration must not depend on a domain type that may change after it. */
export const titlesWithoutTheirSaga: Migration = {
  version: MigrationVersion(18),
  name: MigrationName('titles-without-their-saga'),
  migrate: async ({ db }) => {
    const updates: Update[] = [
      ...(await db.collection('books').get()).docs.flatMap((doc) => {
        const data = bookUpdate(doc.data())
        return data ? [{ ref: doc.ref, data }] : []
      }),
      ...(await db.collection('series').get()).docs.flatMap((doc) => {
        const data = catalogueUpdate(doc.data())
        return data ? [{ ref: doc.ref, data }] : []
      }),
    ]

    for (const slice of chunk(updates, BATCH_SIZE)) {
      const batch = db.batch()
      for (const { ref, data } of slice) batch.update(ref, data)
      await batch.commit()
    }
    return { ok: true, transformed: updates.length }
  },
}
