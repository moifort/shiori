import type { WriteBatch } from 'firebase-admin/firestore'
import type { SeriesId } from '~/domain/series/types'
import type { SeriesOpinion } from '~/domain/series-opinion/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { evictFromRequestCache, memoizedPerRequest } from '~/system/request-cache'
import { deleteInBatches, genericDataConverter, withoutAbsentFields } from '~/utils/firestore'

// Flat, like every other collection, and keyed by the pair rather than given a
// random id: one reader holds exactly one opinion of one saga, so the pair IS
// the identity and a query to find it would be a query to find what we can name.
const opinions = () =>
  db().collection('series-opinions').withConverter(genericDataConverter<SeriesOpinion>())

const documentId = (userId: UserId, seriesId: SeriesId) => `${userId}--${seriesId}`

const allCacheKey = (userId: UserId) => `series-opinions:all:${userId}`

// The series tab reads every opinion at once, then the saga screen reads one of
// them in the same request. Memoizing the scan means they cost one query between
// them rather than one plus a lookup.
export const findAllByUser = (userId: UserId): Promise<SeriesOpinion[]> =>
  memoizedPerRequest(allCacheKey(userId), async () => {
    const snapshot = await opinions().where('userId', '==', userId).get()
    return snapshot.docs.map((doc) => doc.data())
  })

export const findBy = async (userId: UserId, seriesId: SeriesId): Promise<SeriesOpinion | null> =>
  (await findAllByUser(userId)).find((opinion) => opinion.seriesId === seriesId) ?? null

export const save = async (opinion: SeriesOpinion, batch?: WriteBatch): Promise<SeriesOpinion> => {
  const ref = opinions().doc(documentId(opinion.userId, opinion.seriesId))
  const document = withoutAbsentFields(opinion)
  if (batch) batch.set(ref, document)
  else await ref.set(document)
  evictFromRequestCache(allCacheKey(opinion.userId))
  return opinion
}

// An opinion with nothing left in it is deleted rather than stored empty: a
// document saying "no rating, not a favourite" is what an absent document
// already says, and keeping it would bill a read for nothing on every tab open.
export const remove = async (
  userId: UserId,
  seriesId: SeriesId,
  batch?: WriteBatch,
): Promise<void> => {
  const ref = opinions().doc(documentId(userId, seriesId))
  if (batch) batch.delete(ref)
  else await ref.delete()
  evictFromRequestCache(allCacheKey(userId))
}

export const removeAllByUser = async (userId: UserId): Promise<void> => {
  const snapshot = await opinions().where('userId', '==', userId).get()
  await deleteInBatches(snapshot.docs.map((doc) => doc.ref))
  evictFromRequestCache(allCacheKey(userId))
}
