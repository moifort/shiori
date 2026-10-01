import { catalogueKeyOf } from '~/domain/series/primitives'
import type { SeriesEdition as Edition, Series, SeriesMiss } from '~/domain/series/types'
import { db } from '~/system/firebase'
import { evictFromRequestCache, isInRequestCache, memoizedPerRequest } from '~/system/request-cache'
import { genericDataConverter, withoutAbsentFields } from '~/utils/firestore'

// A single global collection, separate from `books`. A catalogue entry is
// a fact about the world with no reference to any reader, so one document serves
// everyone and the AI call that produced it is paid once rather than once per
// reader. It is never exposed through library sharing.
//
// One document per saga and edition language, under `catalogueKeyOf`: a
// translation is its own list of volumes.
const series = () => db().collection('series').withConverter(genericDataConverter<Series>())

const cacheKey = ({ id, language }: Edition) => `series:${catalogueKeyOf(id, language)}`

export const findById = (edition: Edition): Promise<Series | null> =>
  memoizedPerRequest(cacheKey(edition), async () => {
    const doc = await series().doc(catalogueKeyOf(edition.id, edition.language)).get()
    return doc.data() ?? null
  })

// One getAll for a page of sagas rather than a lookup per row: the series tab
// resolves every saga the reader follows in a single billed round trip. It
// shares the per-saga memo with `findById` both ways — a saga already read in
// this request is not fetched again, and one fetched here answers a later
// lookup — so the tab and a saga screen in the same request read each once.
export const findManyByIds = async (editions: readonly Edition[]): Promise<Series[]> => {
  const wanted = [
    ...new Map(
      editions.map((edition) => [catalogueKeyOf(edition.id, edition.language), edition]),
    ).values(),
  ]
  const missing = wanted.filter((edition) => !isInRequestCache(cacheKey(edition)))
  const fetched = new Map<string, Series | null>()
  if (missing.length > 0) {
    const snapshots = await db().getAll(
      ...missing.map((edition) => series().doc(catalogueKeyOf(edition.id, edition.language))),
    )
    for (const [index, snapshot] of snapshots.entries()) {
      const edition = missing[index]
      const entry = (snapshot.data() as Series | undefined) ?? null
      fetched.set(cacheKey(edition), entry)
      memoizedPerRequest(cacheKey(edition), async () => entry)
    }
  }
  const entries = await Promise.all(
    wanted.map((edition) =>
      fetched.has(cacheKey(edition)) ? (fetched.get(cacheKey(edition)) ?? null) : findById(edition),
    ),
  )
  return entries.filter((entry): entry is Series => entry !== null)
}

// Drops the memoized absence before returning. A scan looks the saga up, finds
// nothing, catalogues it, and the resolver that renders the book reads it back
// in the same request — without this it would read the `null` from before the
// write and show a freshly catalogued saga as uncatalogued.
export const save = async (entry: Series): Promise<Series> => {
  await series().doc(catalogueKeyOf(entry.id, entry.language)).set(withoutAbsentFields(entry))
  evictFromRequestCache(cacheKey(entry))
  return entry
}

// What the catalogue call found nothing on, beside the catalogues rather than in
// them: an empty catalogue would mark the saga as known for good. Shared like a
// catalogue, keyed like one, and holding no reference to any reader.
const misses = () =>
  db().collection('series-misses').withConverter(genericDataConverter<SeriesMiss>())

export const findMiss = async ({ id, language }: Edition): Promise<SeriesMiss | null> =>
  (await misses().doc(catalogueKeyOf(id, language)).get()).data() ?? null

export const saveMiss = async (miss: SeriesMiss): Promise<void> => {
  await misses().doc(catalogueKeyOf(miss.id, miss.language)).set(withoutAbsentFields(miss))
}
