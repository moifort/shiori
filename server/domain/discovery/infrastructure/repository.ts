import type {
  AuthorWatch,
  DiscoveryReader,
  KeptReleaseDescription,
  SagaWatch,
} from '~/domain/discovery/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
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

export const findWatches = async (keys: readonly string[]): Promise<SagaWatch[]> => {
  const unique = [...new Set(keys)]
  if (unique.length === 0) return []
  const snapshots = await db().getAll(...unique.map((key) => watches().doc(key)))
  // Typed loosely by getAll, though each ref carries the converter.
  return snapshots.flatMap((snapshot) => {
    const watch = snapshot.data() as SagaWatch | undefined
    return watch ? [watch] : []
  })
}

export const saveWatch = async (watch: SagaWatch): Promise<void> => {
  await watches().doc(watch.key).set(withoutAbsentFields(watch))
}

export const findAuthorWatches = async (keys: readonly string[]): Promise<AuthorWatch[]> => {
  const unique = [...new Set(keys)]
  if (unique.length === 0) return []
  const snapshots = await db().getAll(...unique.map((key) => authorWatches().doc(key)))
  // Typed loosely by getAll, though each ref carries the converter.
  return snapshots.flatMap((snapshot) => {
    const watch = snapshot.data() as AuthorWatch | undefined
    return watch ? [watch] : []
  })
}

export const saveAuthorWatch = async (watch: AuthorWatch): Promise<void> => {
  await authorWatches().doc(watch.key).set(withoutAbsentFields(watch))
}

export const findReader = async (userId: UserId): Promise<DiscoveryReader | undefined> =>
  (await readers().doc(userId).get()).data()

/** Every reader, for the scheduled passes. One document per reader, read once
 *  per run. */
export const findAllReaders = async (): Promise<DiscoveryReader[]> =>
  (await readers().get()).docs.map((doc) => doc.data())

export const saveReader = async (reader: DiscoveryReader): Promise<DiscoveryReader> => {
  await readers().doc(reader.userId).set(withoutAbsentFields(reader))
  return reader
}

export const removeReader = async (userId: UserId): Promise<void> => {
  await readers().doc(userId).delete()
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
