import type { Brand } from 'ts-brand'
import type { UserId } from '~/domain/shared/types'

/** An App Store product identifier, e.g. `"com.polyforms.vinarium.app.premium.yearly"`. */
export type ProductId = Brand<string, 'ProductId'>

/** Apple's identifier for the whole entitlement chain — stable across every
 *  renewal, so it is what identifies *the* entitlement rather than one payment. */
export type OriginalTransactionId = Brand<string, 'OriginalTransactionId'>

/** The UUID handed to StoreKit at purchase time and returned inside the signed
 *  transaction. Derived from the account's id, it is what ties a payment made on
 *  an Apple account to an account of ours — without it, a signed transaction is
 *  just proof that *somebody* paid. */
export type AppAccountToken = Brand<string, 'AppAccountToken'>

/** Which store sold the subscription. Absent on an entitlement recorded before Google Play
 *  sold any: those were all the App Store's. */
export type EntitlementStore = 'app-store' | 'google-play'

/** What the App Store or Google Play sold, as we recorded it. One document per account: an
 *  account has at most one entitlement, and a renewal overwrites it in place.
 *  `revokedAt` is set on a refund or a family-sharing removal — Premium ends then
 *  and there, whatever `expiresAt` still says. `startedAt` is when the chain
 *  began (Apple's `originalPurchaseDate`, a free trial's start included), stable
 *  across renewals; absent on an entitlement recorded before it was kept. */
export type Entitlement = {
  userId: UserId
  productId: ProductId
  /** Apple's original transaction id, or the Play purchase token: what names the purchase
   *  chain in the store that sold it. */
  originalTransactionId: OriginalTransactionId
  appAccountToken: AppAccountToken
  expiresAt: Date
  revokedAt?: Date
  startedAt?: Date
  updatedAt: Date
  store?: EntitlementStore
}
