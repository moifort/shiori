import type { AudibleConnection } from '~/domain/audible/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { evictFromRequestCache, memoizedPerRequest } from '~/system/request-cache'
import { genericDataConverter, withoutAbsentFields } from '~/utils/firestore'

// One document per reader, whose id IS the userId: a reader has one Audible
// account, so there is nothing else to key it on and nothing to query.
const connections = () =>
  db().collection('audible-connections').withConverter(genericDataConverter<AudibleConnection>())

const cacheKey = (userId: UserId) => `audible:connection:${userId}`

// Memoized for the request: an import reads the connection to decrypt the
// credentials and writes it back with the rotated access token, and the settings
// screen reads it again alongside. One read between them.
export const findByUser = (userId: UserId): Promise<AudibleConnection | undefined> =>
  memoizedPerRequest(cacheKey(userId), async () => (await connections().doc(userId).get()).data())

/** Every reader's connection, for the nightly job — the one caller that works
 *  across accounts rather than inside one.
 *
 *  A whole-collection read rather than a filtered query, deliberately. Firestore
 *  drops documents missing the field from both `!=` and `orderBy`, so selecting
 *  on `autoSync` server-side would silently skip exactly the connections made
 *  before the setting existed: the readers the sync was built for. At one
 *  document per reader this costs one read each, once a night. When that stops
 *  being cheap, backfill `autoSync` onto every account and filter here.
 *
 *  Not memoized: the job passes over each reader once, and holding a whole
 *  collection in the request cache for the rest of the run buys nothing. */
export const findAll = async (): Promise<AudibleConnection[]> =>
  (await connections().get()).docs.map((doc) => doc.data())

export const save = async (connection: AudibleConnection): Promise<AudibleConnection> => {
  // A full set rather than a merge: finishing a sign-in has to make `pending`
  // disappear, and a merge would leave the spent code verifier behind forever.
  await connections().doc(connection.userId).set(withoutAbsentFields(connection))
  evictFromRequestCache(cacheKey(connection.userId))
  return connection
}

export const remove = async (userId: UserId): Promise<void> => {
  await connections().doc(userId).delete()
  evictFromRequestCache(cacheKey(userId))
}
