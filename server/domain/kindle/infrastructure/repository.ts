import type { KindleConnection } from '~/domain/kindle/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import {
  evictFromRequestCache,
  memoizedPerRequest,
  rememberInRequestCache,
} from '~/system/request-cache'
import { genericDataConverter, withoutAbsentFields } from '~/utils/firestore'

// One document per reader, whose id IS the userId: a reader has one Kindle
// library, so there is nothing else to key it on and nothing to query.
const connections = () =>
  db().collection('kindle-connections').withConverter(genericDataConverter<KindleConnection>())

const cacheKey = (userId: UserId) => `kindle:connection:${userId}`

// Memoized for the request: a pass reads the connection to open the
// credentials, then writes it back with what it saw, and the screen reads it
// again alongside.
export const findByUser = (userId: UserId): Promise<KindleConnection | undefined> =>
  memoizedPerRequest(cacheKey(userId), async () => (await connections().doc(userId).get()).data())

/** Every reader's connection, for the nightly job — the one caller that works
 *  across accounts. A whole-collection read rather than a query on `autoSync`,
 *  which Firestore would silently skip on documents missing the field. One read
 *  per connected reader, once a night. Not memoized: the job passes over each
 *  reader once. */
export const findAll = async (): Promise<KindleConnection[]> =>
  (await connections().get()).docs.map((doc) => doc.data())

export const save = async (connection: KindleConnection): Promise<KindleConnection> => {
  // A full set rather than a merge: finishing a sign-in has to make `pending`
  // disappear, and a merge would leave the spent code verifier behind forever.
  await connections().doc(connection.userId).set(withoutAbsentFields(connection))
  rememberInRequestCache(cacheKey(connection.userId), Promise.resolve(connection))
  return connection
}

export const remove = async (userId: UserId): Promise<void> => {
  await connections().doc(userId).delete()
  evictFromRequestCache(cacheKey(userId))
}
