import type { WriteBatch } from 'firebase-admin/firestore'
import type { AnalyticsView } from '~/domain/analytics/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { findDocuments, genericDataConverter, withoutAbsentFields } from '~/utils/firestore'

// One document per reader, keyed by the reader, in a flat top-level collection.
// It is derived data: deleting it loses nothing, the next dashboard read rebuilds it.
const views = () =>
  db().collection('analytics').withConverter(genericDataConverter<AnalyticsView>())

export const findByUser = async (userId: UserId): Promise<AnalyticsView | undefined> =>
  (await views().doc(userId).get()).data()

/** Several readers' views in one round trip, for the friends list. Absent
 *  views are simply missing from the map. */
export const findByUsers = (userIds: readonly UserId[]): Promise<AnalyticsView[]> =>
  findDocuments(views(), userIds)

export const save = async (view: AnalyticsView): Promise<AnalyticsView> => {
  await views().doc(view.userId).set(withoutAbsentFields(view))
  return view
}

// A merge, so the flag lands on an existing view without erasing it, and creates
// a bare stale document when there is none yet.
export const markStale = async (userId: UserId, batch?: WriteBatch): Promise<void> => {
  const ref = views().doc(userId)
  if (batch) batch.set(ref, { userId, stale: true }, { merge: true })
  else await ref.set({ userId, stale: true }, { merge: true })
}

export const remove = async (userId: UserId): Promise<void> => {
  await views().doc(userId).delete()
}
