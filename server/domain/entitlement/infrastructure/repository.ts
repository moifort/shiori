import type { AppAccountToken, Entitlement, EntitlementStore } from '~/domain/entitlement/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { evictFromRequestCache, memoizedPerRequest } from '~/system/request-cache'
import {
  compositeId,
  deleteAllOwnedBy,
  genericDataConverter,
  transactionally,
  withoutAbsentFields,
} from '~/utils/firestore'

const entitlements = () =>
  db().collection('entitlements').withConverter(genericDataConverter<Entitlement>())

const storeOf = (entitlement: Pick<Entitlement, 'store'>): EntitlementStore =>
  entitlement.store ?? 'app-store'

// One document per account and per store. The App Store's keeps the id it always had, the
// account's own; Google Play's is keyed by the pair. A Play entitlement recorded before the
// split sits under the account's id, marked `google-play`, until its next save moves it.
const idOf = (userId: UserId, store: EntitlementStore) =>
  store === 'app-store' ? (userId as string) : compositeId(userId, store)

const cacheKey = (userId: UserId) => `entitlements:${userId}`

// Every entitlement the account holds, one per store at most. One query, memoized: the plan
// is read by the scan gate and again by the `quota` query, on one read per request.
export const findAllBy = (userId: UserId): Promise<Entitlement[]> =>
  memoizedPerRequest(cacheKey(userId), async () =>
    (await entitlements().where('userId', '==', userId).get()).docs.map((doc) => doc.data()),
  )

// Record what a store vouched for, atomically against what its document already holds:
// `reconcile` decides what is kept (an older payload keeps the stored one). Saved whole, never
// merged: an omitted key erases the stored field, which is what an absent `revokedAt` means.
// Answers what is now recorded.
export const saveReconciled = async (
  incoming: Entitlement,
  reconcile: (stored: Entitlement | undefined, incoming: Entitlement) => Entitlement | 'stale',
): Promise<Entitlement> => {
  const store = storeOf(incoming)
  const ownRef = entitlements().doc(idOf(incoming.userId, store))
  const accountRef = entitlements().doc(incoming.userId)
  const kept = await transactionally(async (tx) => {
    const [own, account] = await Promise.all([tx.get(ownRef), tx.get(accountRef)])
    // A Play entitlement recorded before the split, under the account's id.
    const legacyPlay = account.data()?.store === 'google-play' ? account.data() : undefined
    const stored =
      store === 'google-play' ? (own.data() ?? legacyPlay) : legacyPlay ? undefined : own.data()
    const decided = reconcile(stored, incoming)
    const result = decided === 'stale' ? (stored as Entitlement) : decided
    if (legacyPlay) {
      // Moved to its own id: Play's save writes it there below, the App Store's copies it
      // there before taking the account's id for itself.
      if (store === 'google-play') tx.delete(accountRef)
      else
        tx.set(
          entitlements().doc(idOf(incoming.userId, 'google-play')),
          withoutAbsentFields(legacyPlay),
        )
    }
    if (decided !== 'stale' || legacyPlay) tx.set(ownRef, withoutAbsentFields(result))
    return result
  })
  evictFromRequestCache(cacheKey(incoming.userId))
  return kept
}

// Forget every entitlement the account holds (account deletion). This only forgets our
// record of the purchase; the store still owns the subscription's lifecycle, so an active
// subscription keeps renewing until cancelled there. Idempotent.
export const removeAll = async (userId: UserId): Promise<void> => {
  await deleteAllOwnedBy(entitlements(), userId)
  evictFromRequestCache(cacheKey(userId))
}

// The webhook's way in: Apple's notification names the account only through the
// account token it carries, and that derivation is one-way. A single-field
// equality query, which Firestore indexes on its own.
export const findByAppAccountToken = async (
  token: AppAccountToken,
): Promise<Entitlement | undefined> => {
  const snap = await entitlements().where('appAccountToken', '==', token).limit(1).get()
  return snap.docs[0]?.data()
}

// The whole collection, for the admin metrics refresh and the scheduled passes. One document
// per subscriber and store ever, so streaming it stays a small, single query.
export const findAll = async (): Promise<Entitlement[]> =>
  (await entitlements().get()).docs.map((doc) => doc.data())
