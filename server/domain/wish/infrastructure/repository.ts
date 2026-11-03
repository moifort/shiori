import type { UserId } from '~/domain/shared/types'
import type { Wish, WishId } from '~/domain/wish/types'
import { db } from '~/system/firebase'
import { evictFromRequestCache, memoizedPerRequest } from '~/system/request-cache'
import { deleteInBatches, genericDataConverter, withoutAbsentFields } from '~/utils/firestore'

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

export const remove = async (userId: UserId, ids: readonly WishId[]): Promise<void> => {
  await deleteInBatches(ids.map((id) => wishes().doc(id)))
  evictFromRequestCache(allCacheKey(userId))
}

export const removeAllByUser = async (userId: UserId): Promise<void> => {
  const snapshot = await wishes().where('userId', '==', userId).get()
  await deleteInBatches(snapshot.docs.map((doc) => doc.ref))
  evictFromRequestCache(allCacheKey(userId))
}
