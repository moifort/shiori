import type {
  DocumentData,
  DocumentReference,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
  Transaction,
  WriteBatch,
} from 'firebase-admin/firestore'
import { chunk } from 'lodash-es'
import type { BeverageId } from '~/domain/beverage/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { evictFromRequestCache, isInRequestCache, memoizedPerRequest } from '~/system/request-cache'

// Generic Firestore converter that preserves type information when reading
// documents and recursively turns Timestamp instances back into JS Date.
// Pattern from https://github.com/moifort/price-it back/src/utils/firestore.ts
export const genericDataConverter = <T extends DocumentData>(): FirestoreDataConverter<T> => ({
  toFirestore: (data: T) => data,
  fromFirestore: (snapshot: QueryDocumentSnapshot) => toDate(snapshot.data()) as T,
})

const toDate = (value: unknown): unknown => {
  if (!value || typeof value !== 'object') return value
  const obj = value as Record<string, unknown>
  for (const key of Object.keys(obj)) {
    const v = obj[key] as { toDate?: () => Date } | unknown
    if (v && typeof v === 'object' && typeof (v as { toDate?: unknown }).toDate === 'function') {
      obj[key] = (v as { toDate: () => Date }).toDate()
    } else if (v && typeof v === 'object') {
      toDate(v)
    }
  }
  return obj
}

// Firestore rejects `undefined` field values outright. An absent domain field is
// meant to disappear from the document, which is exactly what dropping the key
// does on a full `set`.
export const withoutAbsentFields = <T extends DocumentData>(data: T): T =>
  Object.fromEntries(Object.entries(data).filter(([, value]) => value !== undefined)) as T

// Firestore batches accept at most 500 operations.
const BATCH_LIMIT = 400

// Persist many records with bounded write concurrency — individual sets, not a
// batch (the row count on an import/restore can exceed the 500-op batch cap).
export const bulkSave = async <T>(rows: T[], save: (row: T) => Promise<unknown>): Promise<void> => {
  for (const slice of chunk(rows, 50)) await Promise.all(slice.map((row) => save(row)))
}

export const deleteInBatches = async (refs: DocumentReference[]): Promise<void> => {
  for (const slice of chunk(refs, BATCH_LIMIT)) {
    const batch = db().batch()
    for (const ref of slice) batch.delete(ref)
    await batch.commit()
  }
}

// Repository for collections holding one record per (user, beverage) pair, stored
// under the deterministic doc id `${userId}_${beverageId}` — the shared shape of
// the tasting/gift/recommendation satellite collections.
export const userBeverageRecordRepository = <T extends { userId: UserId; beverageId: BeverageId }>(
  collectionName: string,
) => {
  const records = () => db().collection(collectionName).withConverter(genericDataConverter<T>())
  const docId = (userId: UserId, beverageId: BeverageId) => `${userId}_${beverageId}`
  const allCacheKey = (userId: UserId) => `${collectionName}:all:${userId}`

  const findAllByUser = (userId: UserId): Promise<T[]> =>
    memoizedPerRequest(allCacheKey(userId), async () => {
      const snap = await records().where('userId', '==', userId).get()
      return snap.docs.map((doc) => doc.data())
    })

  return {
    findAllByUser,
    findBy: async (userId: UserId, beverageId: BeverageId): Promise<T | null> => {
      const doc = await records().doc(docId(userId, beverageId)).get()
      return doc.data() ?? null
    },
    // Batch-load the records for a page of beverages with a single getAll — one
    // read per id, no full-collection scan. Missing docs come back undefined. When
    // the full scan already ran in this request, reuse it: zero extra reads. The
    // read-then-write flow that would make this stale (a mutation writing here and
    // reindexing the wine in the same request) is covered: every write below drops
    // the memoized scan.
    findManyByBeverageIds: async (userId: UserId, beverageIds: BeverageId[]): Promise<T[]> => {
      if (beverageIds.length === 0) return []
      if (isInRequestCache(allCacheKey(userId))) {
        const wanted = new Set(beverageIds)
        return (await findAllByUser(userId)).filter((record) => wanted.has(record.beverageId))
      }
      const refs = beverageIds.map((beverageId) => records().doc(docId(userId, beverageId)))
      const snaps = await db().getAll(...refs)
      return snaps.map((snap) => snap.data()).filter((data): data is T => data !== undefined)
    },
    // Writes drop the memoized scan so a read later in the same request sees them.
    // Search reindexing does exactly that: it rewrites the wine's terms right
    // after a satellite changed, and a stale scan would index the previous state.
    save: async (record: T, batch?: WriteBatch): Promise<T> => {
      const ref = records().doc(docId(record.userId, record.beverageId))
      if (batch) batch.set(ref, record)
      else await ref.set(record)
      evictFromRequestCache(allCacheKey(record.userId))
      return record
    },
    remove: async (userId: UserId, beverageId: BeverageId, batch?: WriteBatch): Promise<void> => {
      const ref = records().doc(docId(userId, beverageId))
      if (batch) batch.delete(ref)
      else await ref.delete()
      evictFromRequestCache(allCacheKey(userId))
    },
    removeAllByUser: async (userId: UserId): Promise<void> => {
      const snap = await records().where('userId', '==', userId).get()
      await deleteInBatches(snap.docs.map((doc) => doc.ref))
      evictFromRequestCache(allCacheKey(userId))
    },
  }
}

// Runs `enlist` against a fresh WriteBatch and commits it once: either every
// enlisted write lands or none does. Reads inside `enlist` see pre-batch state —
// batched writes are invisible until commit. Firestore caps a batch at 500
// writes; callers enlist a handful of documents, far below the cap.
export const atomically = async <T>(enlist: (batch: WriteBatch) => Promise<T>): Promise<T> => {
  const batch = db().batch()
  const result = await enlist(batch)
  await batch.commit()
  return result
}

// Read-then-write in one go, with the read protected against a concurrent writer.
// A batch cannot do this: its reads see pre-batch state, so two callers
// incrementing the same counter would both read the same value and one increment
// would be lost. Firestore retries the body on contention, so it must stay pure
// beyond its own reads and writes.
export const transactionally = <T>(run: (tx: Transaction) => Promise<T>): Promise<T> =>
  db().runTransaction(run)
