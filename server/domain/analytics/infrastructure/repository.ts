import { gunzipSync, gzipSync } from 'node:zlib'
import {
  type DocumentData,
  FieldValue,
  type QueryDocumentSnapshot,
  type WriteBatch,
} from 'firebase-admin/firestore'
import type { AnalyticsView, SharedHearts, SharedHeartsState } from '~/domain/analytics/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import {
  atomically,
  findDocuments,
  genericDataConverter,
  withoutAbsentFields,
} from '~/utils/firestore'

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

// Merges, so each flag lands on an existing document without erasing it, and
// creates a bare flagged one when there is none yet. The view and the hearts
// are flagged together, in one batch: no write can reach one and miss the other.
export const markStale = async (userId: UserId, batch?: WriteBatch): Promise<void> => {
  const flag = (into: WriteBatch) => {
    into.set(views().doc(userId), { userId, stale: true }, { merge: true })
    into.set(
      heartsFlags().doc(userId),
      { userId, writes: FieldValue.increment(1) },
      { merge: true },
    )
  }
  if (batch) flag(batch)
  else await atomically(async (own) => flag(own))
}

export const remove = async (userId: UserId): Promise<void> => {
  await Promise.all([views().doc(userId).delete(), hearts().doc(userId).delete()])
}

// The hearts a reader's friends' feeds draw, one document per reader. Derived
// as the view is: deleting it loses nothing, the next feed rebuilds it. The
// books are stored as one gzipped JSON string rather than as maps: whole
// records, as the feeds serve them, would be indexed field by field and a
// reader who hearts a lot could pass Firestore's 1 MiB; compressed they are a
// fraction of it.
type StoredHearts = SharedHeartsState & { hearts?: string }

const hearts = () =>
  db()
    .collection('shared-hearts')
    .withConverter({
      toFirestore: (stored: StoredHearts) => stored,
      fromFirestore: (snapshot: QueryDocumentSnapshot) => storedHeartsOf(snapshot.data()),
    })

// The same collection unconverted, for the flag's increment sentinel.
const heartsFlags = () => db().collection('shared-hearts')

// Not the generic converter: it would walk the compressed string's fields.
const storedHeartsOf = ({ refreshedAt, ...rest }: DocumentData): StoredHearts =>
  ({
    ...rest,
    ...(refreshedAt
      ? { refreshedAt: refreshedAt instanceof Date ? refreshedAt : refreshedAt.toDate() }
      : {}),
  }) as StoredHearts

/** The largest compressed projection kept, under Firestore's 1 MiB a document
 *  with room for the fields beside it. */
const MAX_STORED_HEARTS = 900_000

// An instant, as JSON writes a Date: read back as one.
const INSTANT = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$/

const encoded = (shared: SharedHearts) => gzipSync(JSON.stringify(shared)).toString('base64')

const decoded = (stored: string): SharedHearts =>
  JSON.parse(gunzipSync(Buffer.from(stored, 'base64')).toString('utf8'), (_key, value) =>
    typeof value === 'string' && INSTANT.test(value) ? new Date(value) : value,
  )

/** Several readers' projections in one round trip, each with what tells it
 *  fresh. A reader none was ever built or flagged for is missing; one only
 *  flagged so far comes without its hearts. */
export const findHearts = async (
  userIds: readonly UserId[],
): Promise<(SharedHeartsState & { shared?: SharedHearts })[]> =>
  (await findDocuments(hearts(), userIds)).map(({ hearts: stored, ...state }) => ({
    ...state,
    ...(stored ? { shared: decoded(stored) } : {}),
  }))

/** Keeps the projection, never touching the count of writes that flag it.
 *  Answers how many times too large it is instead when it cannot be kept. */
export const saveHearts = async (
  shared: SharedHearts,
  state: Required<Pick<SharedHeartsState, 'version' | 'builtFrom' | 'refreshedAt'>>,
): Promise<'saved' | { tooLarge: number }> => {
  const stored = encoded(shared)
  if (stored.length > MAX_STORED_HEARTS) return { tooLarge: stored.length / MAX_STORED_HEARTS }
  await hearts()
    .doc(shared.userId)
    .set({ userId: shared.userId, ...state, hearts: stored }, { merge: true })
  return 'saved'
}
