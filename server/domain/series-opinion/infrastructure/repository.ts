import type { SeriesOpinion } from '~/domain/series-opinion/types'
import { db } from '~/system/firebase'
import { genericDataConverter } from '~/utils/firestore'
import { oneDocumentPerReaderAndKey } from '~/utils/reader-documents'

// Flat, like every other collection, and keyed by the pair rather than given a
// random id: one reader holds exactly one opinion of one saga, so the pair IS
// the identity and a query to find it would be a query to find what we can name.
//
// The series tab reads every opinion at once, then the saga screen reads one of
// them in the same request. Memoizing the scan means they cost one query between
// them rather than one plus a lookup. Shared in flight with the requests the
// app sends alongside, which want them as well.
//
// An opinion with nothing left in it is removed rather than stored empty: a
// document saying "no rating, not a favourite" is what an absent document
// already says, and keeping it would bill a read for nothing on every tab open.
const opinions = oneDocumentPerReaderAndKey({
  collection: () =>
    db().collection('series-opinions').withConverter(genericDataConverter<SeriesOpinion>()),
  keyOf: (opinion) => opinion.seriesId,
  cacheTag: 'series-opinions',
  idOf: (userId, seriesId) => `${userId}--${seriesId}`,
})

export const { findAllByUser, save, remove, removeAllByUser } = opinions

/** One document, read by its id: the saga screen used to read every opinion of
 *  the reader to keep one. Taken from the scan when this request already holds it. */
export const findBy = opinions.findOne
