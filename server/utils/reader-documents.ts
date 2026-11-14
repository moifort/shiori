import type { CollectionReference, DocumentData, WriteBatch } from 'firebase-admin/firestore'
import {
  evictFromRequestCache,
  isInRequestCache,
  memoizedPerRequest,
  rememberInRequestCache,
} from '~/system/request-cache'
import { compositeId, deleteAllOwnedBy, withoutAbsentFields } from '~/utils/firestore'

// The two shapes most private documents take, written once for every
// repository that stores one: a document per reader, and a document per reader
// and thing they hold an opinion of. Each repository keeps its own collection,
// opened in its own file, and exports the functions it always had.

type OwnedDocument = DocumentData & { userId: string }

/** One document per reader, whose id IS the reader: a connection, an
 *  entitlement — there is one of each, nothing else to key it on and nothing
 *  to query. Memoized for the request; a write is remembered, so the rest of
 *  the request reads what was written without asking Firestore again. */
export const oneDocumentPerReader = <T extends OwnedDocument>({
  collection,
  cacheKeyOf,
}: {
  collection: () => CollectionReference<T>
  cacheKeyOf: (userId: T['userId']) => string
}) => ({
  findByUser: (userId: T['userId']): Promise<T | undefined> =>
    memoizedPerRequest(cacheKeyOf(userId), async () =>
      (await collection().doc(userId).get()).data(),
    ),

  /** Every reader's document, for a nightly job: one read each. Not memoized —
   *  the job passes over each reader once. */
  findAll: async (): Promise<T[]> => (await collection().get()).docs.map((doc) => doc.data()),

  /** A full set rather than a merge: a field the document no longer holds has
   *  to disappear from what is stored. */
  save: async (document: T): Promise<T> => {
    await collection().doc(document.userId).set(withoutAbsentFields(document))
    rememberInRequestCache(cacheKeyOf(document.userId), Promise.resolve(document))
    return document
  },

  remove: async (userId: T['userId']): Promise<void> => {
    await collection().doc(userId).delete()
    evictFromRequestCache(cacheKeyOf(userId))
  },
})

/** One document per reader and thing — a saga they judged, an author they
 *  hearted, a book they turned down — keyed by the pair, which IS the
 *  identity: the thing not held has no document at all, rather than one
 *  saying so.
 *
 *  With `cacheTag`, the reader's documents are read once per request, shared
 *  in flight with the requests the app sends alongside, and every write
 *  forgets them; one document is then taken from that read when the request
 *  holds it. */
export const oneDocumentPerReaderAndKey = <T extends OwnedDocument>({
  collection,
  keyOf,
  cacheTag,
  legacyIdOf,
}: {
  collection: () => CollectionReference<T>
  keyOf: (document: T) => string
  cacheTag?: string
  /** The id a document had before ids took one separator. Read where the
   *  current one holds nothing, and removed with it, until the migration that
   *  moves the documents has run. */
  legacyIdOf?: (userId: T['userId'], key: string) => string
}) => {
  const idOf = (userId: T['userId'], key: string) => compositeId(userId, key)
  const allCacheKey = (userId: T['userId']) => `${cacheTag}:all:${userId}`
  const forget = (userId: T['userId']) => {
    if (cacheTag) evictFromRequestCache(allCacheKey(userId))
  }
  // A document stored under both ids — written again before the migration
  // moved it — answers once, as written last: under its current id.
  const readAll = async (userId: T['userId']): Promise<T[]> => {
    const { docs } = await collection().where('userId', '==', userId).get()
    if (!legacyIdOf) return docs.map((doc) => doc.data())
    const byKey = new Map<string, T>()
    for (const doc of docs) {
      const document = doc.data()
      const key = keyOf(document)
      if (!byKey.has(key) || doc.ref.id === idOf(userId, key)) byKey.set(key, document)
    }
    return [...byKey.values()]
  }

  const findAllByUser = (userId: T['userId']): Promise<T[]> =>
    cacheTag
      ? memoizedPerRequest(allCacheKey(userId), () => readAll(userId), { shareInFlight: true })
      : readAll(userId)

  return {
    findAllByUser,

    findOne: async (userId: T['userId'], key: string): Promise<T | undefined> => {
      if (cacheTag && isInRequestCache(allCacheKey(userId)))
        return (await findAllByUser(userId)).find((document) => keyOf(document) === key)
      const stored = (await collection().doc(idOf(userId, key)).get()).data()
      if (stored || !legacyIdOf) return stored
      return (await collection().doc(legacyIdOf(userId, key)).get()).data()
    },

    /** Enlisted in the caller's batch when it gives one. */
    save: async (document: T, batch?: WriteBatch): Promise<T> => {
      const ref = collection().doc(idOf(document.userId, keyOf(document)))
      const data = withoutAbsentFields(document)
      if (batch) batch.set(ref, data)
      else await ref.set(data)
      forget(document.userId)
      return document
    },

    /** Under the legacy id too, or a document the migration had not moved
     *  yet would come back. */
    remove: async (userId: T['userId'], key: string, batch?: WriteBatch): Promise<void> => {
      const refs = [idOf(userId, key), ...(legacyIdOf ? [legacyIdOf(userId, key)] : [])].map((id) =>
        collection().doc(id),
      )
      for (const ref of refs) {
        if (batch) batch.delete(ref)
        else await ref.delete()
      }
      forget(userId)
    },

    removeAllByUser: async (userId: T['userId']): Promise<void> => {
      await deleteAllOwnedBy(collection(), userId)
      forget(userId)
    },
  }
}
