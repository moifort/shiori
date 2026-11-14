import { chunk } from 'lodash-es'
import type {
  AwaitedEdition,
  AwaitedEditionId,
  EditionPassState,
} from '~/domain/awaited-edition/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { evictFromRequestCache, memoizedPerRequest } from '~/system/request-cache'
import {
  deleteInBatches,
  genericDataConverter,
  transactionally,
  withoutAbsentFields,
} from '~/utils/firestore'

// Private: one document per reader, book and format, naming its reader.
const awaitedEditions = () =>
  db().collection('awaited-editions').withConverter(genericDataConverter<AwaitedEdition>())

const allCacheKey = (userId: UserId) => `awaited-editions:all:${userId}`

// The Découvrir strip and a book's page read the same list in one request, and
// Découvrir's other sections, sent alongside, read it too.
export const findAllByUser = (userId: UserId): Promise<AwaitedEdition[]> =>
  memoizedPerRequest(
    allCacheKey(userId),
    async () => {
      const snapshot = await awaitedEditions().where('userId', '==', userId).get()
      return snapshot.docs.map((doc) => doc.data())
    },
    { shareInFlight: true },
  )

/** Every awaited edition, for the scheduled passes: read once per run. */
export const findAll = async (): Promise<AwaitedEdition[]> =>
  (await awaitedEditions().get()).docs.map((doc) => doc.data())

/** The editions awaited since a moment: a range on `awaitedAt`, which its
 *  automatic single-field index serves. */
export const findAwaitedSince = async (since: Date): Promise<AwaitedEdition[]> =>
  (await awaitedEditions().where('awaitedAt', '>', since).get()).docs.map((doc) => doc.data())

/** Every edition awaited under these watch keys, thirty keys a query (the most
 *  an `in` takes). Within a query Firestore answers in document order, as it
 *  does for the whole collection; across several, they are put back in it. */
export const findByWatchKeys = async (keys: readonly string[]): Promise<AwaitedEdition[]> => {
  const unique = [...new Set(keys)]
  if (unique.length === 0) return []
  const parts = await Promise.all(
    chunk(unique, 30).map(async (part) =>
      (await awaitedEditions().where('watchKey', 'in', part).get()).docs.map((doc) => doc.data()),
    ),
  )
  if (parts.length === 1) return parts[0] ?? []
  return parts.flat().sort((left, right) => (left.id < right.id ? -1 : left.id > right.id ? 1 : 0))
}

// One document, written by the hourly pass for the next one. A migration that
// ever deletes or rewrites edition watches must delete it too; without it, the
// next pass reads every edition awaited, as it did before it existed.
const passState = () =>
  db()
    .collection('edition-pass')
    .withConverter(genericDataConverter<EditionPassState>())
    .doc('hourly')

export const findPassState = async (): Promise<EditionPassState | undefined> =>
  (await passState().get()).data()

export const savePassState = async (state: EditionPassState): Promise<void> => {
  await passState().set(withoutAbsentFields(state))
}

export const save = async (awaited: AwaitedEdition): Promise<AwaitedEdition> => {
  await awaitedEditions().doc(awaited.id).set(withoutAbsentFields(awaited))
  evictFromRequestCache(allCacheKey(awaited.userId))
  return awaited
}

/** Stamp the edition's alert on what is stored when the transaction runs, not
 *  on the pass's copy: an edition the reader stopped awaiting meanwhile stays
 *  gone. Undefined when it is. */
export const markNotified = async (
  id: AwaitedEditionId,
  notifiedAt: Date,
): Promise<AwaitedEdition | undefined> => {
  const marked = await transactionally(async (tx) => {
    const ref = awaitedEditions().doc(id)
    const stored = (await tx.get(ref)).data()
    if (!stored) return undefined
    const next = { ...stored, notifiedAt }
    tx.set(ref, withoutAbsentFields(next))
    return next
  })
  if (marked) evictFromRequestCache(allCacheKey(marked.userId))
  return marked
}

export const remove = async (userId: UserId, ids: readonly AwaitedEditionId[]): Promise<void> => {
  await deleteInBatches(ids.map((id) => awaitedEditions().doc(id)))
  evictFromRequestCache(allCacheKey(userId))
}

export const removeAllByUser = async (userId: UserId): Promise<void> => {
  const snapshot = await awaitedEditions().where('userId', '==', userId).get()
  await deleteInBatches(snapshot.docs.map((doc) => doc.ref))
  evictFromRequestCache(allCacheKey(userId))
}
