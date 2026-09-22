import type { WriteBatch } from 'firebase-admin/firestore'
import type { AnalyticsView } from '~/domain/analytics/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { genericDataConverter, withoutAbsentFields } from '~/utils/firestore'

// One document per reader, keyed by the reader, in a flat top-level collection.
// It is derived data: deleting it loses nothing, the next dashboard read rebuilds it.
const views = () =>
  db().collection('analytics').withConverter(genericDataConverter<AnalyticsView>())

export const findByUser = async (userId: UserId): Promise<AnalyticsView | null> =>
  (await views().doc(userId).get()).data() ?? null

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
