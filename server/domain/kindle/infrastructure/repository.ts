import type { KindleConnection, ReadKindleTitle } from '~/domain/kindle/types'
import { db } from '~/system/firebase'
import { findDocuments, genericDataConverter, withoutAbsentFields } from '~/utils/firestore'
import { oneDocumentPerReader } from '~/utils/reader-documents'

// One document per reader, whose id IS the userId: a reader has one Kindle
// library, so there is nothing else to key it on and nothing to query.
//
// Memoized for the request: a pass reads the connection to open the
// credentials, then writes it back with what it saw, and the screen reads it
// again alongside. Saved whole, as the Audible connection is: finishing a
// sign-in has to make `pending` disappear.
const connections = oneDocumentPerReader({
  collection: () =>
    db().collection('kindle-connections').withConverter(genericDataConverter<KindleConnection>()),
  cacheKeyOf: (userId) => `kindle:connection:${userId}`,
})

export const { findByUser, save, remove } = connections

/** Every reader's connection, for the nightly job — the one caller that works
 *  across accounts. A whole-collection read rather than a query on `autoSync`,
 *  which Firestore would silently skip on documents missing the field. One read
 *  per connected reader, once a night. Not memoized: the job passes over each
 *  reader once. */
export const findAll = connections.findAll

// Shared, keyed by the ASIN, holding no reference to any reader.
const readTitles = () =>
  db().collection('kindle-titles').withConverter(genericDataConverter<ReadKindleTitle>())

export const findReadTitles = (asins: readonly string[]): Promise<ReadKindleTitle[]> =>
  findDocuments(readTitles(), asins)

export const saveReadTitle = async (read: ReadKindleTitle): Promise<void> => {
  await readTitles().doc(read.asin).set(withoutAbsentFields(read))
}
