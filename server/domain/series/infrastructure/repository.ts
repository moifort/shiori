import type { Series, SeriesId } from '~/domain/series/types'
import { db } from '~/system/firebase'
import { evictFromRequestCache, isInRequestCache, memoizedPerRequest } from '~/system/request-cache'
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
// resolves every saga the reader follows in a single billed round trip. It
// shares the per-saga memo with `findById` both ways — a saga already read in
// this request is not fetched again, and one fetched here answers a later
// lookup — so the tab and a saga screen in the same request read each once.
export const findManyByIds = async (seriesIds: readonly SeriesId[]): Promise<Series[]> => {
  const wanted = [...new Set(seriesIds)]
  const missing = wanted.filter((seriesId) => !isInRequestCache(cacheKey(seriesId)))
  const fetched = new Map<SeriesId, Series | null>()
  if (missing.length > 0) {
    const snapshots = await db().getAll(...missing.map((seriesId) => series().doc(seriesId)))
    for (const [index, snapshot] of snapshots.entries()) {
      const seriesId = missing[index]
      const entry = (snapshot.data() as Series | undefined) ?? null
      fetched.set(seriesId, entry)
      memoizedPerRequest(cacheKey(seriesId), async () => entry)
    }
  }
  const entries = await Promise.all(
    wanted.map((seriesId) =>
      fetched.has(seriesId) ? (fetched.get(seriesId) ?? null) : findById(seriesId),
    ),
  )
  return entries.filter((entry): entry is Series => entry !== null)
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
