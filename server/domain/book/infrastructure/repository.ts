import type { WriteBatch } from 'firebase-admin/firestore'
import { inItsEdition, mediaFor, shelfDateOf } from '~/domain/book/business-rules'
import type {
  Book,
  BookFormat,
  BookId,
  BookMedium,
  ReadingStatus,
  SyncedBookRemoval,
  SyncSource,
} from '~/domain/book/types'
import type { SagaKey, SeriesId } from '~/domain/series/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import {
  evictFromRequestCache,
  isInRequestCache,
  memoizedPerRequest,
  reviseInRequestCache,
} from '~/system/request-cache'
import {
  deleteInBatches,
  genericDataConverter,
  transactionally,
  withoutAbsentFields,
} from '~/utils/firestore'

// One flat collection for every reader, never a subcollection: a book carries its
// owner in `userId`, and a library is an equality query on that field, which the
// automatic single-field index answers without a composite one.
//
// Stored with the date the Library tab shelves it on, derived on every write: the
// tab pages on it with a Firestore cursor rather than scanning the library for
// each page. A storage field only — it is stripped on the way back to a `Book`.
//
// A record written before paper and screen were told apart from the format —
// `ebook`, and no `media` — reads as one written now: migration 014 rewrites
// them, and this covers the minutes between a deploy and its migration.
type StoredBook = Omit<Book, 'format' | 'media'> & {
  format: BookFormat | 'ebook'
  media?: BookMedium[]
  shelvedAt: Date
}

const books = () => db().collection('books').withConverter(genericDataConverter<StoredBook>())

const stored = (book: Book): StoredBook =>
  withoutAbsentFields({ ...book, shelvedAt: shelfDateOf(book) })

const asBook = ({ shelvedAt: _, format, media, ...book }: StoredBook): Book =>
  format === 'ebook'
    ? { ...book, format: 'book', media: mediaFor('book', [...(media ?? []), 'digital']) }
    : { ...book, format, media: mediaFor(format, media) }

const ownedBy = (userId: UserId) => books().where('userId', '==', userId)

const allCacheKey = (userId: UserId) => `books:all:${userId}`

/** The books this request read or wrote one by one, by id, as it last saw
 *  them: what `save` measures a write against. Outside a request there is
 *  none, and a save writes the whole record as it always did. */
const seenCopies = (userId: UserId): Map<BookId, Book> =>
  memoizedPerRequest(`books:seen:${userId}`, () => new Map<BookId, Book>())

/** Books a query just read, recorded as seen: a direct save of one of them
 *  later in the request then carries only the fields it changed, as for a
 *  book read by id. Every read path goes through here — a book read some
 *  other way would be written whole over whatever landed since. */
const seen = (read: Book[]): Book[] => {
  for (const book of read) seenCopies(book.userId).set(book.id, book)
  return read
}

// The library list, the series sections and the home screen all want the same
// rows in one request. Memoizing the scan means they cost one query between
// them rather than one each. Shared in flight too: the app opens on some ten
// requests at once — Découvrir's sections, the dashboard — each of which wants
// the whole library, and a friend's shelf is read by two of them.
export const findAllByUser = (userId: UserId): Promise<Book[]> =>
  memoizedPerRequest(
    allCacheKey(userId),
    async () => {
      const snapshot = await ownedBy(userId).get()
      return snapshot.docs.map((doc) => asBook(doc.data()))
    },
    { shareInFlight: true },
  )

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
  view: { statuses?: readonly ReadingStatus[]; format?: BookFormat },
  limit: number,
  after?: BookId,
): Promise<{ books: Book[]; hasMore: boolean }> => {
  let query = ownedBy(userId)
  // `in` is served by the same composite index as an equality on the status.
  if (view.statuses?.length === 1) query = query.where('status', '==', view.statuses[0])
  else if (view.statuses) query = query.where('status', 'in', [...view.statuses])
  if (view.format) query = query.where('format', '==', view.format)
  query = query.orderBy('shelvedAt', 'desc').orderBy('title', 'asc')
  if (after) {
    const cursor = await books().doc(after).get()
    if (cursor.exists && cursor.data()?.userId === userId) query = query.startAfter(cursor)
  }
  const snapshot = await query.limit(limit + 1).get()
  const rows = seen(snapshot.docs.map((doc) => asBook(doc.data())))
  return { books: rows.slice(0, limit), hasMore: rows.length > limit }
}

// The id alone reaches any reader's book now that the collection is shared, so
// a book owned by someone else answers exactly like one that does not exist.
//
// Taken from the library when this request already holds it: a sync that loaded
// the shelf and then moves forty books would otherwise read each of them twice.
export const findById = async (userId: UserId, bookId: BookId): Promise<Book | undefined> => {
  if (isInRequestCache(allCacheKey(userId)))
    return (await findAllByUser(userId)).find((book) => book.id === bookId)
  const book = (await books().doc(bookId).get()).data()
  if (book?.userId !== userId) return undefined
  const read = asBook(book)
  seenCopies(userId).set(bookId, read)
  return read
}

/** The reader's books among `ids`, in the order asked, by id: one document read
 *  each. A book owned by someone else, or gone, is left out. */
export const findByIds = async (userId: UserId, ids: readonly BookId[]): Promise<Book[]> => {
  if (ids.length === 0) return []
  const snapshots = await db().getAll(...ids.map((id) => books().doc(id)))
  return seen(
    snapshots.flatMap((snapshot) => {
      const book = snapshot.data() as StoredBook | undefined
      return book?.userId === userId ? [asBook(book)] : []
    }),
  )
}

// One edition's volumes alone, by a query on its series id: the saga screen
// used to load the whole library to keep a handful of rows. Taken from the
// library when this request already holds it, where filtering in memory costs
// nothing.
//
// Equalities only, which Firestore serves by merging its automatic single-field
// indexes: no composite index.
export const findBySeries = async (userId: UserId, seriesId: SeriesId): Promise<Book[]> => {
  if (isInRequestCache(allCacheKey(userId)))
    return (await findAllByUser(userId)).filter((book) => book.series?.id === seriesId)
  const snapshot = await ownedBy(userId).where('series.id', '==', seriesId).get()
  return seen(snapshot.docs.map((doc) => asBook(doc.data())))
}

// Every edition's volumes of one saga, by a query on the saga key stored beside
// the id: what removing or merging a whole saga, and a build older than the
// edition ids, ask for.
export const findBySaga = async (userId: UserId, saga: SagaKey): Promise<Book[]> => {
  if (isInRequestCache(allCacheKey(userId)))
    return (await findAllByUser(userId)).filter((book) => book.series?.saga === saga)
  const snapshot = await ownedBy(userId).where('series.saga', '==', saga).get()
  return seen(snapshot.docs.map((doc) => asBook(doc.data())))
}

// Every reader's volumes of one edition: what a saga renamed by its catalogue
// writes its new name into. An equality on the series id alone, served by its
// automatic single-field index.
export const findInSeries = async (seriesId: SeriesId): Promise<Book[]> => {
  const snapshot = await books().where('series.id', '==', seriesId).get()
  return seen(snapshot.docs.map((doc) => asBook(doc.data())))
}

// A direct write revises the memoized scan in place, so a read later in the same
// request sees it without scanning the library again — a sync writing book after
// book, then reading the shelf, does exactly that.
//
// A batched write drops the scan instead. Until the batch commits, Firestore
// still answers with the old document, so a scan taken in between would keep
// the pre-write book for the rest of the request; dropped on every batched
// write, the next read after the commit sees it.
//
// Filed under the edition its own saga, format and language make, whatever the
// caller built: a book whose language or format was corrected moves to the
// series id of its new edition here, so no write can leave a stale id behind.
//
// Two writers never overwrite each other. The nightly Audible and Kindle passes
// read a shelf once and write its books minutes later, and a reader's mutation
// may land in between: a direct write of a book this request read is applied,
// inside a transaction, to the record as it stands now, carrying only the fields
// the writer changed from the copy it read. The pass's listening position and
// the reader's rating both survive; the same field written by both keeps the
// last. A book deleted meanwhile stays deleted. A book never read here — a new
// one — and a batched write, which a transaction cannot join, are written whole.
export const save = async (written: Book, batch?: WriteBatch): Promise<Book> => {
  const book = inItsEdition(written)
  const ref = books().doc(book.id)
  if (batch) {
    batch.set(ref, stored(book))
    seenCopies(book.userId).delete(book.id)
    evictFromRequestCache(allCacheKey(book.userId))
    return book
  }
  const base = await copyRead(book.userId, book.id)
  const saved = base ? await savedOver(base, book) : await ref.set(stored(book)).then(() => book)
  if (!saved) return book
  seenCopies(book.userId).set(saved.id, saved)
  reviseLibrary(book.userId, (library) =>
    library.some((other) => other.id === saved.id)
      ? library.map((other) => (other.id === saved.id ? saved : other))
      : [...library, saved],
  )
  return saved
}

/** The copy of a book this request last read or wrote: its library when it
 *  holds it, else the book read alone. */
const copyRead = async (userId: UserId, bookId: BookId): Promise<Book | undefined> => {
  if (isInRequestCache(allCacheKey(userId))) {
    const held = (await findAllByUser(userId)).find((book) => book.id === bookId)
    if (held) return held
  }
  return seenCopies(userId).get(bookId)
}

/** The fields the writer changed from the copy it read, applied to the record
 *  as it stands, in one transaction. Undefined when the book is gone. */
const savedOver = (base: Book, written: Book): Promise<Book | undefined> =>
  transactionally(async (transaction) => {
    const ref = books().doc(written.id)
    const current = (await transaction.get(ref)).data()
    if (current?.userId !== written.userId) return undefined
    const book = inItsEdition(withChangesOf(base, written, asBook(current)))
    transaction.set(ref, stored(book))
    return book
  })

/** `current` with every field `written` changed from `base`, removals included. */
const withChangesOf = (base: Book, written: Book, current: Book): Book => {
  const merged: Record<string, unknown> = { ...current }
  const from = base as Record<string, unknown>
  const to = written as Record<string, unknown>
  for (const field of new Set([...Object.keys(from), ...Object.keys(to)])) {
    if (JSON.stringify(from[field]) === JSON.stringify(to[field])) continue
    if (to[field] === undefined) delete merged[field]
    else merged[field] = to[field]
  }
  return merged as Book
}

export const remove = async (userId: UserId, bookId: BookId, batch?: WriteBatch): Promise<void> => {
  const ref = books().doc(bookId)
  if (batch) {
    batch.delete(ref)
    seenCopies(userId).delete(bookId)
    evictFromRequestCache(allCacheKey(userId))
    return
  }
  await ref.delete()
  seenCopies(userId).delete(bookId)
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

// Flat too, keyed by reader, source and ASIN: deleting the same title twice
// writes one document, and the pass that brings it back deletes that one.
const syncRemovals = () =>
  db().collection('book-sync-removals').withConverter(genericDataConverter<SyncedBookRemoval>())

const removalId = (userId: UserId, source: SyncSource, asin: string) =>
  `${userId}~${source}~${asin}`

export const saveSyncRemovals = async (
  removals: readonly SyncedBookRemoval[],
  batch?: WriteBatch,
): Promise<void> => {
  for (const removal of removals) {
    const ref = syncRemovals().doc(removalId(removal.userId, removal.source, removal.asin))
    if (batch) batch.set(ref, withoutAbsentFields(removal))
    else await ref.set(withoutAbsentFields(removal))
  }
}

// Two equality filters, which Firestore merges from the single-field indexes.
export const findSyncRemovals = async (
  userId: UserId,
  source: SyncSource,
): Promise<SyncedBookRemoval[]> =>
  (await syncRemovals().where('userId', '==', userId).where('source', '==', source).get()).docs.map(
    (doc) => doc.data(),
  )

export const forgetSyncRemovals = async (
  userId: UserId,
  source: SyncSource,
  asins: readonly string[],
): Promise<void> => {
  await deleteInBatches(asins.map((asin) => syncRemovals().doc(removalId(userId, source, asin))))
}

export const removeAllSyncRemovalsByUser = async (userId: UserId): Promise<void> => {
  const snapshot = await syncRemovals().where('userId', '==', userId).get()
  await deleteInBatches(snapshot.docs.map((doc) => doc.ref))
}
