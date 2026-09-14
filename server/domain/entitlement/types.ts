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

/** What the App Store sold, as we recorded it. One document per account: an
 *  account has at most one entitlement, and a renewal overwrites it in place.
 *  `revokedAt` is set on a refund or a family-sharing removal — Premium ends then
 *  and there, whatever `expiresAt` still says. */
export type Entitlement = {
  userId: UserId
  productId: ProductId
  originalTransactionId: OriginalTransactionId
  appAccountToken: AppAccountToken
  expiresAt: Date
  revokedAt?: Date
  updatedAt: Date
}
