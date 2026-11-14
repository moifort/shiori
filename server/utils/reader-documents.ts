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
  idOf = compositeId,
}: {
  collection: () => CollectionReference<T>
  keyOf: (document: T) => string
  cacheTag?: string
  idOf?: (userId: T['userId'], key: string) => string
}) => {
  const allCacheKey = (userId: T['userId']) => `${cacheTag}:all:${userId}`
  const forget = (userId: T['userId']) => {
    if (cacheTag) evictFromRequestCache(allCacheKey(userId))
  }
  const readAll = async (userId: T['userId']): Promise<T[]> =>
    (await collection().where('userId', '==', userId).get()).docs.map((doc) => doc.data())

  const findAllByUser = (userId: T['userId']): Promise<T[]> =>
    cacheTag
      ? memoizedPerRequest(allCacheKey(userId), () => readAll(userId), { shareInFlight: true })
      : readAll(userId)

  return {
    findAllByUser,

    findOne: async (userId: T['userId'], key: string): Promise<T | undefined> => {
      if (cacheTag && isInRequestCache(allCacheKey(userId)))
        return (await findAllByUser(userId)).find((document) => keyOf(document) === key)
      return (await collection().doc(idOf(userId, key)).get()).data()
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

    remove: async (userId: T['userId'], key: string, batch?: WriteBatch): Promise<void> => {
      const ref = collection().doc(idOf(userId, key))
      if (batch) batch.delete(ref)
      else await ref.delete()
      forget(userId)
    },

    removeAllByUser: async (userId: T['userId']): Promise<void> => {
      await deleteAllOwnedBy(collection(), userId)
      forget(userId)
    },
  }
}
