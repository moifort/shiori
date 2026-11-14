import type { AudibleConnection } from '~/domain/audible/types'
import { db } from '~/system/firebase'
import { genericDataConverter } from '~/utils/firestore'
import { oneDocumentPerUser } from '~/utils/user-documents'

// One document per reader, whose id IS the userId: a reader has one Audible
// account, so there is nothing else to key it on and nothing to query.
//
// Memoized for the request: an import reads the connection to decrypt the
// credentials and writes it back with the rotated access token, and the settings
// screen reads it again alongside. One read between them. A save is remembered
// rather than dropped: an import rotates the token, then records itself on the
// same connection, and must not read it back in between.
//
// Saved whole rather than merged: finishing a sign-in has to make `pending`
// disappear, and a merge would leave the spent code verifier behind forever.
const connections = oneDocumentPerUser({
  collection: () =>
    db().collection('audible-connections').withConverter(genericDataConverter<AudibleConnection>()),
  cacheKeyOf: (userId) => `audible:connection:${userId}`,
})

export const { findByUser, save, remove } = connections

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
export const findAll = connections.findAll
