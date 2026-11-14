import { seriesIdOf } from '~/domain/series/primitives'
import type { SeriesEdition as Edition, Series, SeriesMiss } from '~/domain/series/types'
import { db } from '~/system/firebase'
import { evictFromRequestCache, memoizedPerRequest } from '~/system/request-cache'
import {
  findDocumentsPerRequest,
  genericDataConverter,
  transactionally,
  withoutAbsentFields,
} from '~/utils/firestore'

// A single global collection, separate from `books`. A catalogue entry is
// a fact about the world with no reference to any reader, so one document serves
// everyone and the AI call that produced it is paid once rather than once per
// reader. It is never exposed through library sharing.
//
// One document per saga and edition language, under its series id: a
// translation is its own list of volumes.
const series = () => db().collection('series').withConverter(genericDataConverter<Series>())

const documentIdOf = ({ saga, language }: Edition) => seriesIdOf(saga, language)
const cacheKeyOf = (id: string) => `series:${id}`
const cacheKey = (edition: Edition) => cacheKeyOf(documentIdOf(edition))

export const findById = (edition: Edition): Promise<Series | undefined> =>
  memoizedPerRequest(cacheKey(edition), async () => {
    const doc = await series().doc(documentIdOf(edition)).get()
    return doc.data()
  })

// One getAll for a page of sagas rather than a lookup per row: the series tab
// resolves every saga the reader follows in a single billed round trip. It
// shares the per-saga memo with `findById` both ways — a saga already read in
// this request is not fetched again, and one fetched here answers a later
// lookup — so the tab and a saga screen in the same request read each once,
// and so do two resolvers asking the same sagas side by side.
export const findManyByIds = (editions: readonly Edition[]): Promise<Series[]> =>
  findDocumentsPerRequest(series(), editions.map(documentIdOf), cacheKeyOf)

// A read-modify-write on the catalogue as it stands when the transaction runs:
// a scan, a reader's correction and the hourly release watch write the same
// shared document, and none may write back a copy read before another landed.
// `revise` answers undefined to leave the document as it is, which is then what
// comes back. The memo is dropped either way: a scan looks the saga up, finds
// nothing, catalogues it, and the resolver that renders the book reads it back
// in the same request — it must not read the absence from before the write.
export const revise = async (
  edition: Edition,
  revise: (current: Series | undefined) => Series | undefined,
): Promise<Series | undefined> => {
  const result = await transactionally(async (tx) => {
    const ref = series().doc(documentIdOf(edition))
    const current = (await tx.get(ref)).data()
    const revised = revise(current)
    if (!revised) return current
    tx.set(ref, withoutAbsentFields(revised))
    return revised
  })
  evictFromRequestCache(cacheKey(edition))
  return result
}

// What the catalogue call found nothing on, beside the catalogues rather than in
// them: an empty catalogue would mark the saga as known for good. Shared like a
// catalogue, keyed like one, and holding no reference to any reader.
const misses = () =>
  db().collection('series-misses').withConverter(genericDataConverter<SeriesMiss>())

export const findMiss = async (edition: Edition): Promise<SeriesMiss | undefined> =>
  (await misses().doc(documentIdOf(edition)).get()).data()

export const saveMiss = async (miss: SeriesMiss): Promise<void> => {
  await misses().doc(miss.id).set(withoutAbsentFields(miss))
}
