import type { Narrator, NarratorKey } from '~/domain/narrator/types'
import { db } from '~/system/firebase'
import {
  evictFromRequestCache,
  memoizedManyPerRequest,
  memoizedPerRequest,
} from '~/system/request-cache'
import { genericDataConverter, withoutAbsentFields } from '~/utils/firestore'

// A single global collection, as `authors` is: a narrator's face is a fact
// about the world with no reference to any reader, so one document serves
// everyone. It is never exposed through library sharing.
const narrators = () => db().collection('narrators').withConverter(genericDataConverter<Narrator>())

const cacheKey = (key: NarratorKey) => `narrators:${key}`

export const findByKey = (key: NarratorKey): Promise<Narrator | null> =>
  memoizedPerRequest(cacheKey(key), async () => {
    const doc = await narrators().doc(key).get()
    return doc.data() ?? null
  })

// One getAll for the Library tab's rail rather than a lookup per face, sharing
// the per-narrator memo with `findByKey` both ways.
export const findManyByKeys = async (keys: readonly NarratorKey[]): Promise<Narrator[]> => {
  const entries = await memoizedManyPerRequest(keys, cacheKey, async (missing) => {
    const snapshots = await db().getAll(...missing.map((key) => narrators().doc(key)))
    return snapshots.map((snapshot) => (snapshot.data() as Narrator | undefined) ?? null)
  })
  return entries.filter((entry): entry is Narrator => entry !== null)
}

export const save = async (entry: Narrator): Promise<Narrator> => {
  await narrators().doc(entry.key).set(withoutAbsentFields(entry))
  evictFromRequestCache(cacheKey(entry.key))
  return entry
}
