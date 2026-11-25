import type { GoodreadsImport } from '~/domain/goodreads/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { genericDataConverter } from '~/utils/firestore'
import { oneDocumentPerUser } from '~/utils/user-documents'

/** What is stored: the import, and whether covers are still to be sought, kept
 *  apart as a flag so the scheduled cover pass finds its readers with one query
 *  rather than reading every reader who ever imported. */
type StoredGoodreadsImport = GoodreadsImport & { seekingCovers: boolean }

const collection = () =>
  db().collection('goodreads-imports').withConverter(genericDataConverter<StoredGoodreadsImport>())

// One document per reader, whose id IS the userId: the last Goodreads import,
// what it did and the books whose cover is still to be sought.
const imports = oneDocumentPerUser({
  collection,
  cacheKeyOf: (userId) => `goodreads:import:${userId}`,
})

export const { findByUser, remove } = imports

export const save = async (record: GoodreadsImport): Promise<GoodreadsImport> =>
  imports.save({ ...record, seekingCovers: record.pendingCovers.length > 0 })

/** The readers whose last import still has covers to seek. */
export const findSeekingCovers = async (): Promise<UserId[]> =>
  (await collection().where('seekingCovers', '==', true).select('userId').get()).docs.map(
    (doc) => doc.data().userId,
  )
