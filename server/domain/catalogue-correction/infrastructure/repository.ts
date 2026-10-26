import type { CatalogueCorrection } from '~/domain/catalogue-correction/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { deleteInBatches, genericDataConverter } from '~/utils/firestore'

// Flat, beside the catalogues it describes rather than inside them: a catalogue
// names no reader, and this log is nothing but who did what. Random ids, since
// one reader may correct one field many times.
const corrections = () =>
  db()
    .collection('catalogue-corrections')
    .withConverter(genericDataConverter<CatalogueCorrection>())

export const saveAll = async (entries: readonly CatalogueCorrection[]): Promise<void> => {
  if (entries.length === 0) return
  const batch = db().batch()
  for (const entry of entries) batch.set(corrections().doc(), entry)
  await batch.commit()
}

export const findAllByUser = async (userId: UserId): Promise<CatalogueCorrection[]> => {
  const snapshot = await corrections().where('userId', '==', userId).get()
  return snapshot.docs.map((doc) => doc.data())
}

export const removeAllByUser = async (userId: UserId): Promise<void> => {
  const snapshot = await corrections().where('userId', '==', userId).get()
  await deleteInBatches(snapshot.docs.map((doc) => doc.ref))
}
