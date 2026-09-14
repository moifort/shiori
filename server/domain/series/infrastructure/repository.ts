import type { Series, SeriesId } from '~/domain/series/types'
import { db } from '~/system/firebase'
import { memoizedPerRequest } from '~/system/request-cache'
import { genericDataConverter, withoutAbsentFields } from '~/utils/firestore'

// A single global collection, deliberately outside `users/`. A catalogue entry is
// a fact about the world with no reference to any reader, so one document serves
// everyone and the AI call that produced it is paid once rather than once per
// reader. It is never exposed through library sharing.
const series = () => db().collection('series').withConverter(genericDataConverter<Series>())

export const findById = (seriesId: SeriesId): Promise<Series | null> =>
  memoizedPerRequest(`series:${seriesId}`, async () => {
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

export const save = async (entry: Series): Promise<Series> => {
  await series().doc(entry.id).set(withoutAbsentFields(entry))
  return entry
}
