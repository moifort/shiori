import type { GoodreadsImport } from '~/domain/goodreads/types'
import { db } from '~/system/firebase'
import { genericDataConverter } from '~/utils/firestore'
import { oneDocumentPerUser } from '~/utils/user-documents'

// One document per reader, whose id IS the userId: the last Goodreads import,
// what it did and the books whose cover is still to be sought.
const imports = oneDocumentPerUser({
  collection: () =>
    db().collection('goodreads-imports').withConverter(genericDataConverter<GoodreadsImport>()),
  cacheKeyOf: (userId) => `goodreads:import:${userId}`,
})

export const { findByUser, save, remove } = imports
