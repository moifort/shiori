/** The App Store bundle the signatures must belong to — a code fact, like the
 *  Gemini model name, not an operational setting. */
export const BUNDLE_ID = 'com.polyforms.shiori.app'

/** The app's numeric App Store id, which Apple's verifier needs to check a
 *  Production signature. Printed on the store page, assigned once and never
 *  changed, so it belongs next to the bundle id rather than in a deployment
 *  setting: an unset setting would pin verification to Sandbox and turn away
 *  every real purchase. It was Vinarium's (6789688303) from the scaffold until
 *  2026-11-28: Apple's verifier checks it on every Production notification, so
 *  each renewal, expiry and refund Apple pushed would have been refused. */
export const APP_STORE_ID = 6811938144

/** A purchase, once Apple's signature has been checked and the payload decoded.
 *  Only the fields the subscription domain acts on; everything else in Apple's
 *  payload is dropped at this boundary. Absent dates mean "no such event": a
 *  subscription with no `expiresAt` is not a subscription, and `revokedAt` is set
 *  only on a refund or a family-sharing removal. */
export type AppleTransaction = {
  productId: string
  originalTransactionId: string
  /** The UUID handed to StoreKit at purchase time — how a payment is tied back to
   *  an account. Absent on a purchase made before we started sending it. */
  appAccountToken?: string
  expiresAt?: Date
  revokedAt?: Date
  /** When the chain began, a free trial included: Apple's `originalPurchaseDate`,
   *  the same on every renewal. */
  startedAt?: Date
  /** True while the period this transaction covers is a free trial: nothing has been paid
   *  yet. Absent on a paid period. */
  freeTrial?: boolean
  /** When Apple signed this payload (`signedDate`): what orders two payloads of one chain, so
   *  an old one handed over again never overrides what a newer one said. */
  signedAt?: Date
  /** True when Apple's Sandbox signed it: a TestFlight or App Review purchase, or a
   *  development build's, none of which is paid. Absent on a Production purchase. */
  sandbox?: boolean
}

/** What Apple tells us happened, from an App Store Server Notification. The
 *  notification type is kept raw: the domain re-derives the plan from the
 *  transaction's own dates rather than trusting an event name. */
export type AppleNotification = {
  type: string
  subtype?: string
  transaction?: AppleTransaction
}
