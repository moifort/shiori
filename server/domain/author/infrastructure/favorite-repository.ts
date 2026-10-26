import type { AuthorFavorite, AuthorKey } from '~/domain/author/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { evictFromRequestCache, memoizedPerRequest } from '~/system/request-cache'
import { deleteInBatches, genericDataConverter } from '~/utils/firestore'

// Flat, as every collection is, and keyed by the pair: one reader hearts one
// author once, so the pair is the identity. An author not hearted has no
// document at all, rather than one saying so.
const favorites = () =>
  db().collection('author-favorites').withConverter(genericDataConverter<AuthorFavorite>())

const documentId = (userId: UserId, key: AuthorKey) => `${userId}--${key}`

const allCacheKey = (userId: UserId) => `author-favorites:all:${userId}`

// The Authors tab, the entry screen's rail and an author's page all want the
// reader's hearts: one query between them.
export const findAllByUser = (userId: UserId): Promise<AuthorFavorite[]> =>
  memoizedPerRequest(
    allCacheKey(userId),
    async () => {
      const snapshot = await favorites().where('userId', '==', userId).get()
      return snapshot.docs.map((doc) => doc.data())
    },
    { shareInFlight: true },
  )

export const save = async (favorite: AuthorFavorite): Promise<void> => {
  await favorites().doc(documentId(favorite.userId, favorite.authorKey)).set(favorite)
  evictFromRequestCache(allCacheKey(favorite.userId))
}

export const remove = async (userId: UserId, key: AuthorKey): Promise<void> => {
  await favorites().doc(documentId(userId, key)).delete()
  evictFromRequestCache(allCacheKey(userId))
}

export const removeAllByUser = async (userId: UserId): Promise<void> => {
  const snapshot = await favorites().where('userId', '==', userId).get()
  await deleteInBatches(snapshot.docs.map((doc) => doc.ref))
  evictFromRequestCache(allCacheKey(userId))
}
