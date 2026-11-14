import type { CatalogueCorrection } from '~/domain/catalogue-correction/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { deleteAllOwnedBy, genericDataConverter, setInBatches } from '~/utils/firestore'

// Flat, beside the catalogues it describes rather than inside them: a catalogue
// names no reader, and this log is nothing but who did what. Random ids, since
// one reader may correct one field many times.
const corrections = () =>
  db()
    .collection('catalogue-corrections')
    .withConverter(genericDataConverter<CatalogueCorrection>())

export const saveAll = (entries: readonly CatalogueCorrection[]): Promise<void> =>
  setInBatches(entries.map((entry) => ({ ref: corrections().doc(), data: entry })))

export const removeAllByUser = (userId: UserId): Promise<void> =>
  deleteAllOwnedBy(corrections(), userId)
