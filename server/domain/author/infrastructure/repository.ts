import type { Author, AuthorKey } from '~/domain/author/types'
import { db } from '~/system/firebase'
import { evictFromRequestCache, isInRequestCache, memoizedPerRequest } from '~/system/request-cache'
import { genericDataConverter, withoutAbsentFields } from '~/utils/firestore'

// A single global collection, as `series` is. An author catalogue is a fact
// about the world with no reference to any reader, so one document serves
// everyone and the model call that produced it is paid once. It is never
// exposed through library sharing.
const authors = () => db().collection('authors').withConverter(genericDataConverter<Author>())

const cacheKey = (key: AuthorKey) => `authors:${key}`

export const findByKey = (key: AuthorKey): Promise<Author | null> =>
  memoizedPerRequest(cacheKey(key), async () => {
    const doc = await authors().doc(key).get()
    return doc.data() ?? null
  })

// One getAll for a page of the Authors tab rather than a lookup per row, sharing
// the per-author memo with `findByKey` both ways.
export const findManyByKeys = async (keys: readonly AuthorKey[]): Promise<Author[]> => {
  const wanted = [...new Set(keys)]
  const missing = wanted.filter((key) => !isInRequestCache(cacheKey(key)))
  const fetched = new Map<AuthorKey, Author | null>()
  if (missing.length > 0) {
    const snapshots = await db().getAll(...missing.map((key) => authors().doc(key)))
    for (const [index, snapshot] of snapshots.entries()) {
      const key = missing[index]
      const entry = (snapshot.data() as Author | undefined) ?? null
      fetched.set(key, entry)
      memoizedPerRequest(cacheKey(key), async () => entry)
    }
  }
  const entries = await Promise.all(
    wanted.map((key) => (fetched.has(key) ? (fetched.get(key) ?? null) : findByKey(key))),
  )
  return entries.filter((entry): entry is Author => entry !== null)
}

// Drops the memoized absence, so the page that built the catalogue reads it
// back in the same request.
export const save = async (entry: Author): Promise<Author> => {
  await authors().doc(entry.key).set(withoutAbsentFields(entry))
  evictFromRequestCache(cacheKey(entry.key))
  return entry
}
