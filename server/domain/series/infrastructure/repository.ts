import type { Series, SeriesId } from '~/domain/series/types'
import { db } from '~/system/firebase'
import { evictFromRequestCache, memoizedPerRequest } from '~/system/request-cache'
import { genericDataConverter, withoutAbsentFields } from '~/utils/firestore'

// A single global collection, separate from `books`. A catalogue entry is
// a fact about the world with no reference to any reader, so one document serves
// everyone and the AI call that produced it is paid once rather than once per
// reader. It is never exposed through library sharing.
const series = () => db().collection('series').withConverter(genericDataConverter<Series>())

const cacheKey = (seriesId: SeriesId) => `series:${seriesId}`

export const findById = (seriesId: SeriesId): Promise<Series | null> =>
  memoizedPerRequest(cacheKey(seriesId), async () => {
    const doc = await series().doc(seriesId).get()
    return doc.data() ?? null
  })

// One getAll for a page of sagas rather than a lookup per row: the series tab
// resolves every saga the reader follows in a single billed round trip.
export const findManyByIds = async (seriesIds: readonly SeriesId[]): Promise<Series[]> => {
  if (seriesIds.length === 0) return []
  const refs = seriesIds.map((seriesId) => series().doc(seriesId))
  const snapshots = await db().getAll(...refs)
  return snapshots
    .map((snapshot) => snapshot.data() as Series | undefined)
    .filter((data): data is Series => data !== undefined)
}

// Drops the memoized absence before returning. A scan looks the saga up, finds
// nothing, catalogues it, and the resolver that renders the book reads it back
// in the same request — without this it would read the `null` from before the
// write and show a freshly catalogued saga as uncatalogued.
export const save = async (entry: Series): Promise<Series> => {
  await series().doc(entry.id).set(withoutAbsentFields(entry))
  evictFromRequestCache(cacheKey(entry.id))
  return entry
}
