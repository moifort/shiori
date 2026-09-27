import type { AwaitedEdition, AwaitedEditionId, EditionWatch } from '~/domain/awaited-edition/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { evictFromRequestCache, memoizedPerRequest } from '~/system/request-cache'
import { deleteInBatches, genericDataConverter, withoutAbsentFields } from '~/utils/firestore'

// Private: one document per reader, book and format, naming its reader.
const awaitedEditions = () =>
  db().collection('awaited-editions').withConverter(genericDataConverter<AwaitedEdition>())

// Shared, holding no reference to any reader: keyed by the book, the format
// and the language, so every reader awaiting the same edition converges on one
// document and the call behind it is paid once.
const editionWatches = () =>
  db().collection('edition-watches').withConverter(genericDataConverter<EditionWatch>())

const allCacheKey = (userId: UserId) => `awaited-editions:all:${userId}`

// The Découvrir strip and a book's page read the same list in one request.
export const findAllByUser = (userId: UserId): Promise<AwaitedEdition[]> =>
  memoizedPerRequest(allCacheKey(userId), async () => {
    const snapshot = await awaitedEditions().where('userId', '==', userId).get()
    return snapshot.docs.map((doc) => doc.data())
  })

/** Every awaited edition, for the scheduled passes: read once per run. */
export const findAll = async (): Promise<AwaitedEdition[]> =>
  (await awaitedEditions().get()).docs.map((doc) => doc.data())

export const save = async (awaited: AwaitedEdition): Promise<AwaitedEdition> => {
  await awaitedEditions().doc(awaited.id).set(withoutAbsentFields(awaited))
  evictFromRequestCache(allCacheKey(awaited.userId))
  return awaited
}

export const remove = async (userId: UserId, ids: readonly AwaitedEditionId[]): Promise<void> => {
  await deleteInBatches(ids.map((id) => awaitedEditions().doc(id)))
  evictFromRequestCache(allCacheKey(userId))
}

export const removeAllByUser = async (userId: UserId): Promise<void> => {
  const snapshot = await awaitedEditions().where('userId', '==', userId).get()
  await deleteInBatches(snapshot.docs.map((doc) => doc.ref))
  evictFromRequestCache(allCacheKey(userId))
}

export const findWatches = async (keys: readonly string[]): Promise<EditionWatch[]> => {
  const unique = [...new Set(keys)]
  if (unique.length === 0) return []
  const snapshots = await db().getAll(...unique.map((key) => editionWatches().doc(key)))
  // Typed loosely by getAll, though each ref carries the converter.
  return snapshots.flatMap((snapshot) => {
    const watch = snapshot.data() as EditionWatch | undefined
    return watch ? [watch] : []
  })
}

export const saveWatch = async (watch: EditionWatch): Promise<void> => {
  await editionWatches().doc(watch.key).set(withoutAbsentFields(watch))
}
