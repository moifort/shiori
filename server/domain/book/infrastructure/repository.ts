import type { WriteBatch } from 'firebase-admin/firestore'
import type { Book, BookId } from '~/domain/book/types'
import type { SeriesId } from '~/domain/series/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { evictFromRequestCache, memoizedPerRequest } from '~/system/request-cache'
import { deleteInBatches, genericDataConverter, withoutAbsentFields } from '~/utils/firestore'

// One flat collection for every reader, never a subcollection: a book carries its
// owner in `userId`, and a library is an equality query on that field, which the
// automatic single-field index answers without a composite one.
const books = () => db().collection('books').withConverter(genericDataConverter<Book>())

const ownedBy = (userId: UserId) => books().where('userId', '==', userId)

const allCacheKey = (userId: UserId) => `books:all:${userId}`

// The library list, the series sections and the home screen all want the same
// rows in one request. Memoizing the scan means they cost one query between
// them rather than one each.
export const findAllByUser = (userId: UserId): Promise<Book[]> =>
  memoizedPerRequest(allCacheKey(userId), async () => {
    const snapshot = await ownedBy(userId).get()
    return snapshot.docs.map((doc) => doc.data())
  })

// The id alone reaches any reader's book now that the collection is shared, so
// a book owned by someone else answers exactly like one that does not exist.
export const findById = async (userId: UserId, bookId: BookId): Promise<Book | null> => {
  const book = (await books().doc(bookId).get()).data()
  return book?.userId === userId ? book : null
}

// Resolved from the memoized scan rather than a `where` query. A reader owns a
// handful of volumes per saga out of a library already loaded in this request,
// so filtering in memory costs nothing where a second query costs reads.
export const findBySeries = async (userId: UserId, seriesId: SeriesId): Promise<Book[]> =>
  (await findAllByUser(userId)).filter((book) => book.series?.id === seriesId)

// Writes drop the memoized scan so a read later in the same request sees them —
// a mutation that saves and then returns the refreshed library does exactly that.
export const save = async (book: Book, batch?: WriteBatch): Promise<Book> => {
  const ref = books().doc(book.id)
  const document = withoutAbsentFields(book)
  if (batch) batch.set(ref, document)
  else await ref.set(document)
  evictFromRequestCache(allCacheKey(book.userId))
  return book
}

export const remove = async (userId: UserId, bookId: BookId, batch?: WriteBatch): Promise<void> => {
  const ref = books().doc(bookId)
  if (batch) batch.delete(ref)
  else await ref.delete()
  evictFromRequestCache(allCacheKey(userId))
}

// In batches of a few hundred: a library imported from Audible easily runs past
// the 500 writes one batch accepts.
export const removeAllByUser = async (userId: UserId): Promise<void> => {
  const snapshot = await ownedBy(userId).get()
  await deleteInBatches(snapshot.docs.map((doc) => doc.ref))
  evictFromRequestCache(allCacheKey(userId))
}
