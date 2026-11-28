/** The Play package the purchases must belong to — a code fact, like the bundle id. */
export const PACKAGE_NAME = 'com.polyforms.shiori.app'

/** A Play subscription purchase, once Google answered for its token. Only the fields the
 *  subscription domain acts on; everything else in Google's answer is dropped here. */
export type PlaySubscription = {
  productId: string
  /** The token the purchase is known by — what Play calls the purchase, renewals included. */
  purchaseToken: string
  /** The account id handed to Play Billing at purchase time (`obfuscatedAccountId`): how a
   *  payment is tied back to an account. Absent on a purchase made without one. */
  accountToken?: string
  expiresAt?: Date
  /** Set when Play ended the subscription before its paid period ran out: a refund. */
  revokedAt?: Date
  startedAt?: Date
  /** True while the running period is a free trial: nothing has been paid yet. Absent on a
   *  paid period. */
  freeTrial?: boolean
  /** When Google answered for the token. Google answers with the purchase as it stands now, so
   *  this is what orders it against what was recorded before. */
  signedAt: Date
  /** True on a license tester's purchase, which Play charges nothing for. Absent on a paid
   *  one. */
  sandbox?: boolean
  /** Play cancels and refunds a purchase not acknowledged within three days. */
  needsAcknowledgement: boolean
}
