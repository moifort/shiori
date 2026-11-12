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
  KeptReleaseDescription,
  NarratorWatch,
  ReleaseFormat,
  SagaWatch,
} from '~/domain/discovery/types'
import { RELEASE_FORMATS } from '~/domain/discovery/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import {
  evictFromRequestCache,
  memoizedManyPerRequest,
  memoizedPerRequest,
  rememberInRequestCache,
} from '~/system/request-cache'
import { genericDataConverter, withoutAbsentFields } from '~/utils/firestore'

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

// Shared as the saga watches are: a book's description is a fact about the
// book, keyed by it and the language it is written in, holding no reference to
// any reader, so the model call behind it is paid once.
const descriptions = () =>
  db()
    .collection('release-descriptions')
    .withConverter(genericDataConverter<KeptReleaseDescription>())

// One document per reader, keyed by the reader.
const readers = () =>
  db().collection('discovery-readers').withConverter(genericDataConverter<DiscoveryReader>())

// A watch is memoized for the request under its key, from the moment it is
// asked: the tab's two formats, the year's releases and the calendar, resolved
// side by side in one composed request, read each watch once between them. A
// write forgets it.
export const findWatches = async (keys: readonly string[]): Promise<SagaWatch[]> => {
  const found = await memoizedManyPerRequest(
    keys,
    (key) => `saga-watches:${key}`,
    async (missing) => {
      const snapshots = await db().getAll(...missing.map((key) => watches().doc(key)))
      // Typed loosely by getAll, though each ref carries the converter.
      return snapshots.map((snapshot) => snapshot.data() as SagaWatch | undefined)
    },
  )
  return found.filter((watch): watch is SagaWatch => watch !== undefined)
}

export const saveWatch = async (watch: SagaWatch): Promise<void> => {
  await watches().doc(watch.key).set(withoutAbsentFields(watch))
  evictFromRequestCache(`saga-watches:${watch.key}`)
}

export const findAuthorWatches = async (keys: readonly string[]): Promise<AuthorWatch[]> => {
  const found = await memoizedManyPerRequest(
    keys,
    (key) => `author-watches:${key}`,
    async (missing) => {
      const snapshots = await db().getAll(...missing.map((key) => authorWatches().doc(key)))
      // Typed loosely by getAll, though each ref carries the converter.
      return snapshots.map((snapshot) => snapshot.data() as AuthorWatch | undefined)
    },
  )
  return found.filter((watch): watch is AuthorWatch => watch !== undefined)
}

export const saveAuthorWatch = async (watch: AuthorWatch): Promise<void> => {
  await authorWatches().doc(watch.key).set(withoutAbsentFields(watch))
  evictFromRequestCache(`author-watches:${watch.key}`)
}

export const findNarratorWatches = async (keys: readonly string[]): Promise<NarratorWatch[]> => {
  const found = await memoizedManyPerRequest(
    keys,
    (key) => `narrator-watches:${key}`,
    async (missing) => {
      const snapshots = await db().getAll(...missing.map((key) => narratorWatches().doc(key)))
      // Typed loosely by getAll, though each ref carries the converter.
      return snapshots.map((snapshot) => snapshot.data() as NarratorWatch | undefined)
    },
  )
  return found.filter((watch): watch is NarratorWatch => watch !== undefined)
}

export const saveNarratorWatch = async (watch: NarratorWatch): Promise<void> => {
  await narratorWatches().doc(watch.key).set(withoutAbsentFields(watch))
  evictFromRequestCache(`narrator-watches:${watch.key}`)
}

// The watches looked up before `before` or after `after`, by two range queries
// on `checkedAt`, which its automatic single-field index serves: the stale ones
// and the ones looked up today, without reading the rest.
const checkedOutside = async <T>(
  collection: () => CollectionReference<T>,
  before: Date,
  after: Date,
): Promise<T[]> => {
  const [stale, recent] = await Promise.all([
    collection().where('checkedAt', '<', before).get(),
    collection().where('checkedAt', '>', after).get(),
  ])
  return [...stale.docs, ...recent.docs].map((doc) => doc.data())
}

export const findWatchesCheckedOutside = (before: Date, after: Date): Promise<SagaWatch[]> =>
  checkedOutside(watches, before, after)

export const findAuthorWatchesCheckedOutside = (
  before: Date,
  after: Date,
): Promise<AuthorWatch[]> => checkedOutside(authorWatches, before, after)

export const findNarratorWatchesCheckedOutside = (
  before: Date,
  after: Date,
): Promise<NarratorWatch[]> => checkedOutside(narratorWatches, before, after)

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
  await passState().set(state)
}

const readerCacheKey = (userId: UserId) => `discovery-readers:${userId}`

// Memoized for the request: every section of a composed request asks for it.
export const findReader = (userId: UserId): Promise<DiscoveryReader | undefined> =>
  memoizedPerRequest(readerCacheKey(userId), async () => (await readers().doc(userId).get()).data())

/** Every reader, for the scheduled passes. One document per reader, read once
 *  per run. */
export const findAllReaders = async (): Promise<DiscoveryReader[]> =>
  (await readers().get()).docs.map((doc) => doc.data())

export const saveReader = async (reader: DiscoveryReader): Promise<DiscoveryReader> => {
  await readers().doc(reader.userId).set(withoutAbsentFields(reader))
  rememberInRequestCache(readerCacheKey(reader.userId), Promise.resolve(reader))
  return reader
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

const projectionIdOf = (userId: UserId, format: ReleaseFormat) => `${userId}~${format}`

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
    .set({ ...state, rows })
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

export const findLibraryChanges = async (
  userIds: readonly UserId[],
): Promise<DiscoveryLibraryChange[]> => {
  const unique = [...new Set(userIds)]
  if (unique.length === 0) return []
  const snapshots = await db().getAll(...unique.map((userId) => libraryChanges().doc(userId)))
  // Typed loosely by getAll, though each ref carries the converter.
  return snapshots.flatMap((snapshot) => {
    const change = snapshot.data() as DiscoveryLibraryChange | undefined
    return change ? [change] : []
  })
}

export const saveLibraryChanges = async (
  userIds: readonly UserId[],
  changedAt: Date,
): Promise<void> => {
  const unique = [...new Set(userIds)]
  for (let start = 0; start < unique.length; start += 500) {
    const batch = db().batch()
    for (const userId of unique.slice(start, start + 500))
      batch.set(libraryChanges().doc(userId), { userId, changedAt })
    await batch.commit()
  }
  for (const userId of unique) evictFromRequestCache(libraryChangeCacheKey(userId))
}

export const findDescription = async (key: string): Promise<KeptReleaseDescription | undefined> =>
  (await descriptions().doc(key).get()).data()

export const findDescriptions = async (
  keys: readonly string[],
): Promise<KeptReleaseDescription[]> => {
  const unique = [...new Set(keys)]
  if (unique.length === 0) return []
  const snapshots = await db().getAll(...unique.map((key) => descriptions().doc(key)))
  // Typed loosely by getAll, though each ref carries the converter.
  return snapshots.flatMap((snapshot) => {
    const kept = snapshot.data() as KeptReleaseDescription | undefined
    return kept ? [kept] : []
  })
}

export const saveDescription = async (kept: KeptReleaseDescription): Promise<void> => {
  await descriptions().doc(kept.key).set(withoutAbsentFields(kept))
}
