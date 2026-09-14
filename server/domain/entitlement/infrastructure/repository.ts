import type { AppAccountToken, Entitlement } from '~/domain/entitlement/types'
import type { UserId } from '~/domain/shared/types'
import { db } from '~/system/firebase'
import { evictFromRequestCache, memoizedPerRequest } from '~/system/request-cache'
import { genericDataConverter, withoutAbsentFields } from '~/utils/firestore'

const entitlements = () =>
  db().collection('entitlements').withConverter(genericDataConverter<Entitlement>())

const cacheKey = (userId: UserId) => `entitlement:${userId}`

// Keyed by account: one entitlement each, a renewal overwriting it in place.
// Memoized because the plan is read by the scan gate and again by the `quota`
// query — one read per request, not two.
export const findBy = (userId: UserId): Promise<Entitlement | undefined> =>
  memoizedPerRequest(cacheKey(userId), async () => {
    const doc = await entitlements().doc(userId).get()
    return doc.data()
  })

// The webhook's way in: Apple's notification names the account only through the
// account token it carries, and that derivation is one-way. A single-field
// equality query, which Firestore indexes on its own.
export const findByAppAccountToken = async (
  token: AppAccountToken,
): Promise<Entitlement | undefined> => {
  const snap = await entitlements().where('appAccountToken', '==', token).limit(1).get()
  return snap.docs[0]?.data()
}

// The whole collection, for the admin metrics refresh. One document per
// subscriber ever, so streaming it stays a small, single query.
export const findAll = async (): Promise<Entitlement[]> => {
  const snap = await entitlements().get()
  return snap.docs.map((doc) => doc.data())
}

export const save = async (entitlement: Entitlement): Promise<Entitlement> => {
  // Full `set`, never a merge: an omitted key erases the stored field, which is
  // what an absent `revokedAt` means (a refund reversed is Premium restored).
  await entitlements().doc(entitlement.userId).set(withoutAbsentFields(entitlement))
  evictFromRequestCache(cacheKey(entitlement.userId))
  return entitlement
}

// Drop the account's stored entitlement (account deletion). This only forgets our
// record of the purchase; Apple still owns the subscription's lifecycle, so an
// active subscription keeps renewing until cancelled in the App Store. Idempotent.
export const remove = async (userId: UserId): Promise<void> => {
  await entitlements().doc(userId).delete()
  evictFromRequestCache(cacheKey(userId))
}
