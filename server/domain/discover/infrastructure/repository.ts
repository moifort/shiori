import type { BookPreview, DiscoverFeed, ReleaseWatch } from '~/domain/discover/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { genericDataConverter, withoutAbsentFields } from '~/utils/firestore'

// One document per reader, keyed by the reader.
const feeds = () => db().collection('discover').withConverter(genericDataConverter<DiscoverFeed>())

// Shared documents, holding no reference to any reader: keyed by the work and
// the language, so every reader who follows the same saga converges on one
// document and the call behind it is paid once.
const watches = () =>
  db().collection('release-watches').withConverter(genericDataConverter<ReleaseWatch>())

export const findFeed = async (userId: UserId): Promise<DiscoverFeed | undefined> =>
  (await feeds().doc(userId).get()).data()

/** Every reader's feed, for the scheduled jobs. One document per reader, read
 *  once per run. */
export const findAllFeeds = async (): Promise<DiscoverFeed[]> =>
  (await feeds().get()).docs.map((doc) => doc.data())

export const saveFeed = async (feed: DiscoverFeed): Promise<DiscoverFeed> => {
  await feeds().doc(feed.userId).set(withoutAbsentFields(feed))
  return feed
}

export const removeFeed = async (userId: UserId): Promise<void> => {
  await feeds().doc(userId).delete()
}

export const findWatches = async (keys: readonly string[]): Promise<ReleaseWatch[]> => {
  const unique = [...new Set(keys)]
  if (unique.length === 0) return []
  const snapshots = await db().getAll(...unique.map((key) => watches().doc(key)))
  // Typed loosely by getAll, though each ref carries the converter.
  return snapshots.flatMap((snapshot) => {
    const watch = snapshot.data() as ReleaseWatch | undefined
    return watch ? [watch] : []
  })
}

export const saveWatch = async (watch: ReleaseWatch): Promise<void> => {
  await watches().doc(watch.key).set(withoutAbsentFields(watch))
}

// Shared too: a book built for whoever opens it first, keyed by the book and
// the language its record is written in.
const previews = () =>
  db().collection('book-previews').withConverter(genericDataConverter<BookPreview>())

export const findPreview = async (key: string): Promise<BookPreview | undefined> =>
  (await previews().doc(key).get()).data()

export const savePreview = async (preview: BookPreview): Promise<BookPreview> => {
  await previews().doc(preview.key).set(withoutAbsentFields(preview))
  return preview
}
