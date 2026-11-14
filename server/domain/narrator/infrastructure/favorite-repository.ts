import type { NarratorFavorite } from '~/domain/narrator/types'
import { db } from '~/system/firebase'
import { genericDataConverter } from '~/utils/firestore'
import { oneDocumentPerUserAndKey } from '~/utils/user-documents'

// Flat and keyed by the pair, as the author hearts are: a narrator not hearted
// has no document at all.
const favorites = oneDocumentPerUserAndKey({
  collection: () =>
    db().collection('narrator-favorites').withConverter(genericDataConverter<NarratorFavorite>()),
  keyOf: (favorite) => favorite.narratorKey,
  cacheTag: 'narrator-favorites',
  // Until migration 037 has run in production.
  legacyIdOf: (userId, key) => `${userId}--${key}`,
})

export const { findAllByUser, save, remove, removeAllByUser } = favorites
