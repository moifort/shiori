import type { AppAccountToken, Entitlement } from '~/domain/entitlement/types'
import { db } from '~/system/firebase'
import { genericDataConverter } from '~/utils/firestore'
import { oneDocumentPerUser } from '~/utils/user-documents'

const entitlements = () =>
  db().collection('entitlements').withConverter(genericDataConverter<Entitlement>())

// Keyed by account: one entitlement each, a renewal overwriting it in place.
// Memoized because the plan is read by the scan gate and again by the `quota`
// query — one read per request, not two.
//
// Saved whole, never merged: an omitted key erases the stored field, which is
// what an absent `revokedAt` means (a refund reversed is Premium restored).
//
// Removed with the account. This only forgets our record of the purchase;
// Apple still owns the subscription's lifecycle, so an active subscription
// keeps renewing until cancelled in the App Store. Idempotent.
const byAccount = oneDocumentPerUser({
  collection: entitlements,
  cacheKeyOf: (userId) => `entitlement:${userId}`,
})

export const { save, remove } = byAccount
export const findBy = byAccount.findByUser

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
export const findAll = byAccount.findAll
