/** The App Store bundle the signatures must belong to — a code fact, like the
 *  Gemini model name, not an operational setting. */
export const BUNDLE_ID = 'com.polyforms.shiori.app'

/** The app's numeric App Store id, which Apple's verifier needs to check a
 *  Production signature. Printed on the store page, assigned once and never
 *  changed, so it belongs next to the bundle id rather than in a deployment
 *  setting: an unset setting would pin verification to Sandbox and turn away
 *  every real purchase. */
export const APP_STORE_ID = 6789688303

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
}

/** What Apple tells us happened, from an App Store Server Notification. The
 *  notification type is kept raw: the domain re-derives the plan from the
 *  transaction's own dates rather than trusting an event name. */
export type AppleNotification = {
  type: string
  subtype?: string
  transaction?: AppleTransaction
}
