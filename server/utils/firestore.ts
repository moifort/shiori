import type {
  DocumentData,
  DocumentReference,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
  Transaction,
  WriteBatch,
} from 'firebase-admin/firestore'
import { chunk } from 'lodash-es'
import { db } from '~/system/firebase'

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
//
// Recursive, because the shallow version was not enough: a series catalogue is
// an array of volumes, and a volume with no number (a novella) or no year (one
// not out yet) carries `undefined` INSIDE the array. Firestore then rejects the
// whole document, so one unnumbered volume silently cost an entire saga its
// catalogue.
export const withoutAbsentFields = <T extends DocumentData>(data: T): T => pruneUndefined(data) as T

const pruneUndefined = (value: unknown): unknown => {
  if (Array.isArray(value)) return value.map(pruneUndefined)
  // Dates and other class instances are values, not maps: recursing into them
  // would flatten a Timestamp into a plain object.
  if (value === null || typeof value !== 'object' || value instanceof Date) return value
  return Object.fromEntries(
    Object.entries(value as Record<string, unknown>)
      .filter(([, entry]) => entry !== undefined)
      .map(([key, entry]) => [key, pruneUndefined(entry)]),
  )
}

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
