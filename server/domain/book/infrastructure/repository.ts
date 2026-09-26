import type { WriteBatch } from 'firebase-admin/firestore'
import { shelfDateOf } from '~/domain/book/business-rules'
import type { Book, BookId, ReadingStatus } from '~/domain/book/types'
import type { SeriesId } from '~/domain/series/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import {
  evictFromRequestCache,
  isInRequestCache,
  memoizedPerRequest,
  reviseInRequestCache,
} from '~/system/request-cache'
import { deleteInBatches, genericDataConverter, withoutAbsentFields } from '~/utils/firestore'

// One flat collection for every reader, never a subcollection: a book carries its
// owner in `userId`, and a library is an equality query on that field, which the
// automatic single-field index answers without a composite one.
//
// Stored with the date the Library tab shelves it on, derived on every write: the
// tab pages on it with a Firestore cursor rather than scanning the library for
// each page. A storage field only — it is stripped on the way back to a `Book`.
type StoredBook = Book & { shelvedAt: Date }

const books = () => db().collection('books').withConverter(genericDataConverter<StoredBook>())

const stored = (book: Book): StoredBook =>
  withoutAbsentFields({ ...book, shelvedAt: shelfDateOf(book) })

const asBook = ({ shelvedAt: _, ...book }: StoredBook): Book => book

const ownedBy = (userId: UserId) => books().where('userId', '==', userId)

const allCacheKey = (userId: UserId) => `books:all:${userId}`

// The library list, the series sections and the home screen all want the same
// rows in one request. Memoizing the scan means they cost one query between
// them rather than one each.
export const findAllByUser = (userId: UserId): Promise<Book[]> =>
  memoizedPerRequest(allCacheKey(userId), async () => {
    const snapshot = await ownedBy(userId).get()
    return snapshot.docs.map((doc) => asBook(doc.data()))
  })

/** One page of the Library tab, newest on the shelf first, read with a cursor:
 *  `limit + 1` documents a page, whatever the size of the library, the extra
 *  one only saying whether more follow. `after` is the last book of the page
 *  before; one that is gone restarts from the top.
 *
 *  Ties on the shelf date fall to the title in Firestore's own order, which is
 *  by code point rather than by locale.
 *
 *  Each filter combination needs its composite index (firestore.indexes.json). */
export const findShelfPage = async (
  userId: UserId,
  view: { favorite?: boolean; statuses?: readonly ReadingStatus[] },
  limit: number,
  after?: BookId,
): Promise<{ books: Book[]; hasMore: boolean }> => {
  let query = ownedBy(userId)
  // `in` is served by the same composite index as an equality on the status.
  if (view.statuses?.length === 1) query = query.where('status', '==', view.statuses[0])
  else if (view.statuses) query = query.where('status', 'in', [...view.statuses])
  if (view.favorite) query = query.where('favorite', '==', true)
  query = query.orderBy('shelvedAt', 'desc').orderBy('title', 'asc')
  if (after) {
    const cursor = await books().doc(after).get()
    if (cursor.exists && cursor.data()?.userId === userId) query = query.startAfter(cursor)
  }
  const snapshot = await query.limit(limit + 1).get()
  const rows = snapshot.docs.map((doc) => asBook(doc.data()))
  return { books: rows.slice(0, limit), hasMore: rows.length > limit }
}

// The id alone reaches any reader's book now that the collection is shared, so
// a book owned by someone else answers exactly like one that does not exist.
//
// Taken from the library when this request already holds it: a sync that loaded
// the shelf and then moves forty books would otherwise read each of them twice.
export const findById = async (userId: UserId, bookId: BookId): Promise<Book | null> => {
  if (isInRequestCache(allCacheKey(userId)))
    return (await findAllByUser(userId)).find((book) => book.id === bookId) ?? null
  const book = (await books().doc(bookId).get()).data()
  return book?.userId === userId ? asBook(book) : null
}

// The saga's volumes alone, by a query on the saga: the saga screen used to load
// the whole library to keep a handful of rows. Taken from the library when this
// request already holds it, where filtering in memory costs nothing.
//
// Equalities only, which Firestore serves by merging its automatic single-field
// indexes: no composite index.
export const findBySeries = async (userId: UserId, seriesId: SeriesId): Promise<Book[]> => {
  if (isInRequestCache(allCacheKey(userId)))
    return (await findAllByUser(userId)).filter((book) => book.series?.id === seriesId)
  const snapshot = await ownedBy(userId).where('series.id', '==', seriesId).get()
  return snapshot.docs.map((doc) => asBook(doc.data()))
}

// A direct write revises the memoized scan in place, so a read later in the same
// request sees it without scanning the library again — a sync writing book after
// book, then reading the shelf, does exactly that.
//
// A batched write drops the scan instead. Until the batch commits, Firestore
// still answers with the old document, so a scan taken in between would keep
// the pre-write book for the rest of the request; dropped on every batched
// write, the next read after the commit sees it.
export const save = async (book: Book, batch?: WriteBatch): Promise<Book> => {
  const ref = books().doc(book.id)
  const document = stored(book)
  if (batch) {
    batch.set(ref, document)
    evictFromRequestCache(allCacheKey(book.userId))
    return book
  }
  await ref.set(document)
  reviseLibrary(book.userId, (library) =>
    library.some((other) => other.id === book.id)
      ? library.map((other) => (other.id === book.id ? book : other))
      : [...library, book],
  )
  return book
}

export const remove = async (userId: UserId, bookId: BookId, batch?: WriteBatch): Promise<void> => {
  const ref = books().doc(bookId)
  if (batch) {
    batch.delete(ref)
    evictFromRequestCache(allCacheKey(userId))
    return
  }
  await ref.delete()
  reviseLibrary(userId, (library) => library.filter((book) => book.id !== bookId))
}

const reviseLibrary = (userId: UserId, revise: (library: Book[]) => Book[]) =>
  reviseInRequestCache<Promise<Book[]>>(allCacheKey(userId), (library) => library.then(revise))

// In batches of a few hundred: a library imported from Audible easily runs past
// the 500 writes one batch accepts.
export const removeAllByUser = async (userId: UserId): Promise<void> => {
  const snapshot = await ownedBy(userId).get()
  await deleteInBatches(snapshot.docs.map((doc) => doc.ref))
  evictFromRequestCache(allCacheKey(userId))
}
