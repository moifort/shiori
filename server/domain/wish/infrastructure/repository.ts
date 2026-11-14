import type { WriteBatch } from 'firebase-admin/firestore'
import type { UserId } from '~/domain/shared/types'
import type { Wish, WishId } from '~/domain/wish/types'
import { db } from '~/system/firebase'
import { evictFromRequestCache, memoizedPerRequest } from '~/system/request-cache'
import {
  deleteAllOwnedBy,
  deleteInBatches,
  genericDataConverter,
  withoutAbsentFields,
} from '~/utils/firestore'

// Private: one document per reader and story, naming its reader.
const wishes = () => db().collection('wishes').withConverter(genericDataConverter<Wish>())

const allCacheKey = (userId: UserId) => `wishes:all:${userId}`

// The wishlist and the pile's rail read the same list in one request.
export const findAllByUser = (userId: UserId): Promise<Wish[]> =>
  memoizedPerRequest(
    allCacheKey(userId),
    async () => {
      const snapshot = await wishes().where('userId', '==', userId).get()
      return snapshot.docs.map((doc) => doc.data())
    },
    { shareInFlight: true },
  )

export const save = async (wish: Wish): Promise<Wish> => {
  await wishes().doc(wish.id).set(withoutAbsentFields(wish))
  evictFromRequestCache(allCacheKey(wish.userId))
  return wish
}

// Deletes without reading first: a wish that does not exist is deleted all the
// same, for a write and no read. In the caller's batch when it has one.
export const remove = async (
  userId: UserId,
  ids: readonly WishId[],
  batch?: WriteBatch,
): Promise<void> => {
  const refs = ids.map((id) => wishes().doc(id))
  if (batch) for (const ref of refs) batch.delete(ref)
  else await deleteInBatches(refs)
  evictFromRequestCache(allCacheKey(userId))
}

export const removeAllByUser = async (userId: UserId): Promise<void> => {
  await deleteAllOwnedBy(wishes(), userId)
  evictFromRequestCache(allCacheKey(userId))
}
