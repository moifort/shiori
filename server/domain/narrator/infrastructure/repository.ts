import type { Narrator, NarratorKey } from '~/domain/narrator/types'
import { db } from '~/system/firebase'
import {
  evictFromRequestCache,
  memoizedManyPerRequest,
  memoizedPerRequest,
} from '~/system/request-cache'
import { genericDataConverter, transactionally, withoutAbsentFields } from '~/utils/firestore'

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

// A read-modify-write on the entry as it stands when the transaction runs:
// a page's catalogue call, a reader's correction and a portrait lookup write
// the same shared document, and none may write back a copy read before
// another landed. `revise` answers undefined to leave it as it is, which is
// then what comes back. The memo is dropped either way.
export const revise = async (
  key: NarratorKey,
  revise: (current: Narrator | null) => Narrator | undefined,
): Promise<Narrator | null> => {
  const result = await transactionally(async (tx) => {
    const ref = narrators().doc(key)
    const current = (await tx.get(ref)).data() ?? null
    const revised = revise(current)
    if (!revised) return current
    tx.set(ref, withoutAbsentFields(revised))
    return revised
  })
  evictFromRequestCache(cacheKey(key))
  return result
}
