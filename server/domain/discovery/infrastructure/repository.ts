import type { CollectionReference } from 'firebase-admin/firestore'
import type {
  AuthorWatch,
  DiscoveryPassState,
  DiscoveryReader,
  KeptReleaseDescription,
  NarratorWatch,
  SagaWatch,
} from '~/domain/discovery/types'
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
  await readers().doc(userId).delete()
  evictFromRequestCache(readerCacheKey(userId))
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
