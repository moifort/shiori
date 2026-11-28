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

/** What the App Store or Google Play sold, as we recorded it. One document per account and per
 *  store: an account holds at most one entitlement in each, a renewal overwrites it in place,
 *  and the account is Premium while either is active — an App Store subscription lapsing
 *  never erases a Play one still running.
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
  /** True while the period running is a free trial: the account is Premium but has paid
   *  nothing yet. Absent on a paid period, and on entitlements recorded before it was kept. */
  freeTrial?: boolean
  /** When the store vouched for what is recorded: Apple's `signedDate`, or when Google answered.
   *  A payload signed before it is ignored, so an old transaction handed over again cannot
   *  undo a renewal or a refund. Absent on an entitlement recorded before it was kept. */
  signedAt?: Date
  /** True when nothing was paid for it: the App Store's Sandbox (TestFlight, App Review)
   *  or a Google Play license tester's purchase. Premium all the same. Absent on a paid
   *  purchase, and on entitlements recorded before it was kept. */
  sandbox?: boolean
}

/** Why an account holds Premium without a store having sold it. `testflight`: the account's
 *  email is one of the app's TestFlight testers on App Store Connect. */
export type PremiumGrantSource = 'testflight'

/** Whether an account holds Premium as a TestFlight tester, as App Store Connect last
 *  answered, one document per account. Written for every account without a store
 *  subscription that reaches the server, tester or not, so the answer is asked at most once a
 *  day. App Review accounts are never TestFlight testers, so a reviewer always meets the
 *  subscription as a reader does. */
export type PremiumGrant = {
  userId: UserId
  source: PremiumGrantSource
  /** True while the account's email is a tester's. */
  active: boolean
  /** When App Store Connect was last asked. */
  checkedAt: Date
  /** Since when the account has been a tester without a break. Absent when it is not one. */
  grantedAt?: Date
}
