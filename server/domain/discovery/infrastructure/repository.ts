import { gunzipSync, gzipSync } from 'node:zlib'
import type {
  CollectionReference,
  DocumentData,
  QueryDocumentSnapshot,
} from 'firebase-admin/firestore'
import type {
  AuthorWatch,
  Discovery,
  DiscoveryLibraryChange,
  DiscoveryPassState,
  DiscoveryProjection,
  DiscoveryProjectionState,
  DiscoveryReader,
  NarratorWatch,
  ReleaseFormat,
  SagaWatch,
} from '~/domain/discovery/types'
import { RELEASE_FORMATS } from '~/domain/discovery/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import {
  evictFromRequestCache,
  memoizedPerRequest,
  rememberInRequestCache,
} from '~/system/request-cache'
import {
  compositeId,
  findDocuments,
  findDocumentsPerRequest,
  genericDataConverter,
  setInBatches,
  transactionally,
  withoutAbsentFields,
} from '~/utils/firestore'

// Shared documents, holding no reference to any reader: keyed by the saga and
// the language, so every reader who follows the same saga converges on one
// document and the call behind it is paid once.
const watches = () =>
  db().collection('saga-watches').withConverter(genericDataConverter<SagaWatch>())

// Shared as the saga watches are: keyed by the author, the format and the
// language, holding no reference to any reader.
const authorWatches = () =>
  db().collection('author-watches').withConverter(genericDataConverter<AuthorWatch>())

// Shared as the author watches are: keyed by the narrator and the language,
// holding no reference to any reader.
const narratorWatches = () =>
  db().collection('narrator-watches').withConverter(genericDataConverter<NarratorWatch>())

// One document per reader, keyed by the reader.
const readers = () =>
  db().collection('discovery-readers').withConverter(genericDataConverter<DiscoveryReader>())

// The watches of one kind, saga, author or narrator: the same code over three
// collections.
//
// A watch is memoized for the request under its key, from the moment it is
// asked: the tab's two formats, the year's releases and the calendar, resolved
// side by side in one composed request, read each watch once between them. A
// write forgets it.
//
// The watches looked up before `before` or after `after` are found by two range
// queries on `checkedAt`, which its automatic single-field index serves: the
// stale ones and the ones looked up today, without reading the rest.
const watchesIn = <T extends { key: string; checkedAt: Date }>(
  collection: () => CollectionReference<T>,
  cacheTag: string,
) => {
  const cacheKeyOf = (key: string) => `${cacheTag}:${key}`
  return {
    find: (keys: readonly string[]): Promise<T[]> =>
      findDocumentsPerRequest(collection(), keys, cacheKeyOf),
    save: async (watch: T): Promise<void> => {
      await collection().doc(watch.key).set(withoutAbsentFields(watch))
      evictFromRequestCache(cacheKeyOf(watch.key))
    },
    findCheckedOutside: async (before: Date, after: Date): Promise<T[]> => {
      const [stale, recent] = await Promise.all([
        collection().where('checkedAt', '<', before).get(),
        collection().where('checkedAt', '>', after).get(),
      ])
      return [...stale.docs, ...recent.docs].map((doc) => doc.data())
    },
  }
}

const sagaWatches = watchesIn(watches, 'saga-watches')
const authorWatchesOf = watchesIn(authorWatches, 'author-watches')
const narratorWatchesOf = watchesIn(narratorWatches, 'narrator-watches')

export const {
  find: findWatches,
  save: saveWatch,
  findCheckedOutside: findWatchesCheckedOutside,
} = sagaWatches

export const {
  find: findAuthorWatches,
  save: saveAuthorWatch,
  findCheckedOutside: findAuthorWatchesCheckedOutside,
} = authorWatchesOf

export const {
  find: findNarratorWatches,
  save: saveNarratorWatch,
  findCheckedOutside: findNarratorWatchesCheckedOutside,
} = narratorWatchesOf

// One document, written by the hourly pass for the next one. A migration that
// ever deletes watches must delete it too: it trusts that watches are never
// deleted, and the next pass without it reads every watch followed, as it did
// before it existed.
const passState = () =>
  db()
    .collection('discovery-pass')
    .withConverter(genericDataConverter<DiscoveryPassState>())
    .doc('hourly')

export const findPassState = async (): Promise<DiscoveryPassState | undefined> =>
  (await passState().get()).data()

export const savePassState = async (state: DiscoveryPassState): Promise<void> => {
  await passState().set(withoutAbsentFields(state))
}

const readerCacheKey = (userId: UserId) => `discovery-readers:${userId}`

// Memoized for the request: every section of a composed request asks for it.
export const findReader = (userId: UserId): Promise<DiscoveryReader | undefined> =>
  memoizedPerRequest(readerCacheKey(userId), async () => (await readers().doc(userId).get()).data())

/** Every reader, for the scheduled passes. One document per reader, read once
 *  per run. */
export const findAllReaders = async (): Promise<DiscoveryReader[]> =>
  (await readers().get()).docs.map((doc) => doc.data())

/** Write what the passes need to know of the reader's library, those fields
 *  alone: the alerts and digests a pass recorded meanwhile stay as stored, at
 *  no read. A reader stored for the first time starts with none sent. */
export const saveReaderLibrary = async (
  library: Pick<
    DiscoveryReader,
    'userId' | 'language' | 'sagas' | 'authors' | 'narrators' | 'syncedAt'
  >,
  known: DiscoveryReader | undefined,
): Promise<DiscoveryReader> => {
  const fields = known ? library : { ...library, notified: [] }
  await readers().doc(library.userId).set(withoutAbsentFields(fields), { merge: true })
  const reader: DiscoveryReader = { notified: [], ...known, ...fields }
  rememberInRequestCache(readerCacheKey(library.userId), Promise.resolve(reader))
  return reader
}

/** Rewrite the reader from what is stored when the transaction runs, never
 *  from a copy a pass read earlier: two passes crossing each keep what the
 *  other wrote. `revise` answers undefined to write nothing — a reader deleted
 *  meanwhile is not brought back — and the stored reader is then returned. */
export const reviseReader = async (
  userId: UserId,
  revise: (stored: DiscoveryReader | undefined) => DiscoveryReader | undefined,
): Promise<DiscoveryReader | undefined> => {
  const written = await transactionally(async (tx) => {
    const ref = readers().doc(userId)
    const stored = (await tx.get(ref)).data()
    const revised = revise(stored)
    if (!revised) return stored
    const document = withoutAbsentFields(revised)
    tx.set(ref, document)
    return document
  })
  if (written) rememberInRequestCache(readerCacheKey(userId), Promise.resolve(written))
  else evictFromRequestCache(readerCacheKey(userId))
  return written
}

export const removeReader = async (userId: UserId): Promise<void> => {
  await Promise.all([
    readers().doc(userId).delete(),
    // The projections hold the reader's books: they go with the account.
    ...RELEASE_FORMATS.map((format) => projections().doc(projectionIdOf(userId, format)).delete()),
    libraryChanges().doc(userId).delete(),
  ])
  evictFromRequestCache(readerCacheKey(userId))
  evictFromRequestCache(libraryChangeCacheKey(userId))
}

// The read model of the tab, one document per reader and format. The rows are
// stored as one gzipped JSON string rather than as a map: a tab holds every
// volume of every saga it shows, which as fields would be indexed one by one
// and could pass Firestore's 1 MiB a document; compressed it is a tenth of it.
type StoredProjection = DiscoveryProjectionState & { rows?: string }

const projections = () =>
  db()
    .collection('discovery-projections')
    .withConverter({
      toFirestore: (projection: StoredProjection) => projection,
      fromFirestore: (snapshot: QueryDocumentSnapshot) => storedProjectionOf(snapshot.data()),
    })

// Not the generic converter: it would walk the rows character by character.
const storedProjectionOf = ({ builtAt, ...rest }: DocumentData): StoredProjection =>
  ({ ...rest, builtAt: builtAt instanceof Date ? builtAt : builtAt.toDate() }) as StoredProjection

const projectionIdOf = (userId: UserId, format: ReleaseFormat) => compositeId(userId, format)

/** A projection larger than this is not kept: the tab is worked out on each
 *  opening, as before the projection existed. */
const MAX_STORED_ROWS = 900_000

// An instant, as JSON writes a Date: read back as one.
const INSTANT = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$/

const encodedRows = (discovery: Discovery) => gzipSync(JSON.stringify(discovery)).toString('base64')

const decodedRows = (rows: string): Discovery =>
  JSON.parse(gunzipSync(Buffer.from(rows, 'base64')).toString('utf8'), (_key, value) =>
    typeof value === 'string' && INSTANT.test(value) ? new Date(value) : value,
  )

export const findProjection = async (
  userId: UserId,
  format: ReleaseFormat,
): Promise<DiscoveryProjection | undefined> => {
  const stored = (await projections().doc(projectionIdOf(userId, format)).get()).data()
  if (!stored?.rows) return undefined
  const { rows, ...state } = stored
  return { ...state, discovery: decodedRows(rows) }
}

/** Every projection without its rows, for the hourly pass to tell the stale. */
export const findProjectionStates = async (): Promise<DiscoveryProjectionState[]> =>
  (await projections().select('userId', 'format', 'language', 'day', 'builtAt').get()).docs.map(
    (doc) => storedProjectionOf(doc.data()),
  )

/** Keeps the projection; false when it is too large to keep. */
export const saveProjection = async ({
  discovery,
  ...state
}: DiscoveryProjection): Promise<boolean> => {
  const rows = encodedRows(discovery)
  if (rows.length > MAX_STORED_ROWS) return false
  await projections()
    .doc(projectionIdOf(state.userId, state.format))
    .set(withoutAbsentFields({ ...state, rows }))
  return true
}

// One document per reader, keyed by the reader.
const libraryChanges = () =>
  db()
    .collection('discovery-library-changes')
    .withConverter(genericDataConverter<DiscoveryLibraryChange>())

const libraryChangeCacheKey = (userId: UserId) => `discovery-library-changes:${userId}`

// Memoized for the request: the tab's two formats ask for it side by side.
export const findLibraryChange = (userId: UserId): Promise<DiscoveryLibraryChange | undefined> =>
  memoizedPerRequest(libraryChangeCacheKey(userId), async () =>
    (await libraryChanges().doc(userId).get()).data(),
  )

export const findLibraryChanges = (userIds: readonly UserId[]): Promise<DiscoveryLibraryChange[]> =>
  findDocuments(libraryChanges(), userIds)

export const saveLibraryChanges = async (
  userIds: readonly UserId[],
  changedAt: Date,
): Promise<void> => {
  const unique = [...new Set(userIds)]
  await setInBatches(
    unique.map((userId) => ({ ref: libraryChanges().doc(userId), data: { userId, changedAt } })),
  )
  for (const userId of unique) evictFromRequestCache(libraryChangeCacheKey(userId))
}
