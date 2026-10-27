import type { NarratorFavorite, NarratorKey } from '~/domain/narrator/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { evictFromRequestCache, memoizedPerRequest } from '~/system/request-cache'
import { deleteInBatches, genericDataConverter } from '~/utils/firestore'

// Flat and keyed by the pair, as the author hearts are: a narrator not hearted
// has no document at all.
const favorites = () =>
  db().collection('narrator-favorites').withConverter(genericDataConverter<NarratorFavorite>())

const documentId = (userId: UserId, key: NarratorKey) => `${userId}--${key}`

const allCacheKey = (userId: UserId) => `narrator-favorites:all:${userId}`

export const findAllByUser = (userId: UserId): Promise<NarratorFavorite[]> =>
  memoizedPerRequest(
    allCacheKey(userId),
    async () => {
      const snapshot = await favorites().where('userId', '==', userId).get()
      return snapshot.docs.map((doc) => doc.data())
    },
    { shareInFlight: true },
  )

export const save = async (favorite: NarratorFavorite): Promise<void> => {
  await favorites().doc(documentId(favorite.userId, favorite.narratorKey)).set(favorite)
  evictFromRequestCache(allCacheKey(favorite.userId))
}

export const remove = async (userId: UserId, key: NarratorKey): Promise<void> => {
  await favorites().doc(documentId(userId, key)).delete()
  evictFromRequestCache(allCacheKey(userId))
}

export const removeAllByUser = async (userId: UserId): Promise<void> => {
  const snapshot = await favorites().where('userId', '==', userId).get()
  await deleteInBatches(snapshot.docs.map((doc) => doc.ref))
  evictFromRequestCache(allCacheKey(userId))
}
