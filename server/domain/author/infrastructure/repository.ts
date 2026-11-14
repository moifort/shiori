import type { Author, AuthorKey, AuthorMiss } from '~/domain/author/types'
import { db } from '~/system/firebase'
import {
  evictFromRequestCache,
  memoizedManyPerRequest,
  memoizedPerRequest,
} from '~/system/request-cache'
import { genericDataConverter, transactionally, withoutAbsentFields } from '~/utils/firestore'

// A single global collection, as `series` is. An author catalogue is a fact
// about the world with no reference to any reader, so one document serves
// everyone and the model call that produced it is paid once. It is never
// exposed through library sharing.
const authors = () => db().collection('authors').withConverter(genericDataConverter<Author>())

const cacheKey = (key: AuthorKey) => `authors:${key}`

export const findByKey = (key: AuthorKey): Promise<Author | undefined> =>
  memoizedPerRequest(cacheKey(key), async () => {
    const doc = await authors().doc(key).get()
    return doc.data()
  })

// One getAll for a page of the Authors tab rather than a lookup per row, sharing
// the per-author memo with `findByKey` both ways.
export const findManyByKeys = async (keys: readonly AuthorKey[]): Promise<Author[]> => {
  const entries = await memoizedManyPerRequest(keys, cacheKey, async (missing) => {
    const snapshots = await db().getAll(...missing.map((key) => authors().doc(key)))
    return snapshots.map((snapshot) => snapshot.data() as Author | undefined)
  })
  return entries.filter((entry): entry is Author => entry !== undefined)
}

// Drops the memoized absence, so the page that built the catalogue reads it
// back in the same request.
// A read-modify-write on the entry as it stands when the transaction runs:
// a page's catalogue call, a reader's correction and a portrait lookup write
// the same shared document, and none may write back a copy read before
// another landed. `revise` answers undefined to leave it as it is, which is
// then what comes back. The memo is dropped either way.
export const revise = async (
  key: AuthorKey,
  revise: (current: Author | undefined) => Author | undefined,
): Promise<Author | undefined> => {
  const result = await transactionally(async (tx) => {
    const ref = authors().doc(key)
    const current = (await tx.get(ref)).data()
    const revised = revise(current)
    if (!revised) return current
    tx.set(ref, withoutAbsentFields(revised))
    return revised
  })
  evictFromRequestCache(cacheKey(key))
  return result
}

const misses = () =>
  db().collection('author-misses').withConverter(genericDataConverter<AuthorMiss>())

export const findMiss = async (key: AuthorKey): Promise<AuthorMiss | undefined> =>
  (await misses().doc(key).get()).data()

export const saveMiss = async (miss: AuthorMiss): Promise<void> => {
  await misses().doc(miss.key).set(withoutAbsentFields(miss))
}
