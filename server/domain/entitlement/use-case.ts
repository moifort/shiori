import { isActive } from '~/domain/entitlement/business-rules'
import { EntitlementCommand } from '~/domain/entitlement/command'
import { AppAccountToken } from '~/domain/entitlement/primitives'
import { EntitlementQuery } from '~/domain/entitlement/query'
import type { Entitlement } from '~/domain/entitlement/types'
import { QuotaCommand } from '~/domain/quota/command'
import type { UserId } from '~/domain/shared/types'
import { Apple } from '~/system/apple'
import type { AppleTransaction } from '~/system/apple/types'
import { GooglePlay } from '~/system/google-play'
import type { PlaySubscription } from '~/system/google-play/types'

// A transaction we can act on: signed by Apple, naming an account, and granting
// time (a one-off purchase would carry no expiry — there is none in this app, but
// the wire cannot promise that).
type SubscriptionTransaction = AppleTransaction & { expiresAt: Date; appAccountToken: string }

const grantsTime = (transaction: AppleTransaction): transaction is SubscriptionTransaction =>
  transaction.expiresAt !== undefined && transaction.appAccountToken !== undefined

// Record what the App Store sold and, when it makes the account Premium, hand it
// the Premium welcome. Every sync and every renewal passes here, so the grant
// keeps its own once-only guard rather than guessing a first purchase from the
// event: an account subscribed before the grant existed gets it on its next
// launch.
const recordAndWelcome = async (userId: UserId, transaction: SubscriptionTransaction) => {
  const entitlement = await EntitlementCommand.record(userId, transaction)
  if (isActive(entitlement, new Date())) await QuotaCommand.grantPremiumWelcome(userId)
  return entitlement
}

type PlayGrant = PlaySubscription & { expiresAt: Date; accountToken: string }

const playGrantsTime = (subscription: PlaySubscription): subscription is PlayGrant =>
  subscription.expiresAt !== undefined && subscription.accountToken !== undefined

export namespace EntitlementUseCase {
  // Take the app's word for nothing. The client hands over the transaction the
  // App Store signed for it; this checks that signature, checks the purchase
  // names *this* account, and only then records the Premium.
  //
  // The account-token check is what stops a signed transaction from being
  // replayed onto someone else's account: the token is derived from the account's
  // id, so a purchase made for another account simply does not match.
  export const sync = async (
    userId: UserId,
    signedTransaction: string,
  ): Promise<Entitlement | 'invalid-transaction' | 'transaction-not-yours'> => {
    const transaction = await Apple.verifyTransaction(signedTransaction)
    if (transaction === 'invalid-signature') return 'invalid-transaction'
    if (!grantsTime(transaction)) return 'invalid-transaction'
    if (transaction.appAccountToken !== (EntitlementQuery.tokenFor(userId) as string))
      return 'transaction-not-yours'

    return recordAndWelcome(userId, transaction)
  }

  // The Android app's sync: it hands over the token Play Billing gave its purchase, Google
  // says what that token bought and for which account, and only a purchase naming *this*
  // account is recorded — the same account-token check as the App Store's, carried as Play's
  // obfuscated account id. Google refunds a purchase nobody acknowledges within three days,
  // so a grant is acknowledged here, once recorded.
  export const syncPlay = async (
    userId: UserId,
    purchaseToken: string,
  ): Promise<Entitlement | 'invalid-transaction' | 'transaction-not-yours'> => {
    const subscription = await GooglePlay.verifySubscription(purchaseToken)
    if (subscription === 'invalid-token') return 'invalid-transaction'
    if (!playGrantsTime(subscription)) return 'invalid-transaction'
    if (subscription.accountToken !== (EntitlementQuery.tokenFor(userId) as string))
      return 'transaction-not-yours'

    const entitlement = await EntitlementCommand.recordPlay(userId, subscription)
    if (isActive(entitlement, new Date())) await QuotaCommand.grantPremiumWelcome(userId)
    if (subscription.needsAcknowledgement) await GooglePlay.acknowledge(subscription)
    return entitlement
  }

  // Apply what Apple pushed to the webhook: a renewal, an expiry, a refund. The
  // notification is trusted for its signature alone, and the plan is re-derived
  // from the transaction's own dates rather than from the event name — one code
  // path, whatever Apple calls the event.
  //
  // A notification for an account we have never recorded is acknowledged and
  // dropped: the token is a one-way derivation, so there is nobody to attach it
  // to until the app syncs the purchase itself, which it does on the next launch.
  export const applyNotification = async (
    signedPayload: string,
  ): Promise<'applied' | 'ignored' | 'invalid-notification'> => {
    const notification = await Apple.verifyNotification(signedPayload)
    if (notification === 'invalid-signature') return 'invalid-notification'

    const transaction = notification.transaction
    if (!transaction || !grantsTime(transaction)) return 'ignored'

    const known = await EntitlementQuery.byToken(AppAccountToken(transaction.appAccountToken))
    if (!known) return 'ignored'

    await recordAndWelcome(known.userId, transaction)
    return 'applied'
  }
}
