import {
  earnsPremiumWelcome,
  needsTesterCheck,
  normalizedEmail,
} from '~/domain/entitlement/business-rules'
import { EntitlementCommand } from '~/domain/entitlement/command'
import { AppAccountToken } from '~/domain/entitlement/primitives'
import { EntitlementQuery } from '~/domain/entitlement/query'
import type { Entitlement } from '~/domain/entitlement/types'
import { QuotaCommand } from '~/domain/quota/command'
import type { UserId } from '~/domain/shared/types'
import { Apple } from '~/system/apple'
import type { AppleTransaction } from '~/system/apple/types'
import { AppStoreConnect } from '~/system/appstore-connect'
import { GooglePlay } from '~/system/google-play'
import type { PlaySubscription } from '~/system/google-play/types'
import { createLogger } from '~/system/logger'

const logger = createLogger('entitlement')

// A transaction we can act on: signed by Apple, naming an account, and granting
// time (a one-off purchase would carry no expiry — there is none in this app, but
// the wire cannot promise that).
type SubscriptionTransaction = AppleTransaction & { expiresAt: Date; appAccountToken: string }

const grantsTime = (transaction: AppleTransaction): transaction is SubscriptionTransaction =>
  transaction.expiresAt !== undefined && transaction.appAccountToken !== undefined

// The Premium welcome goes to an account whose Premium has been paid for, never to a free
// trial. Every sync and every renewal passes here, so the grant keeps its own once-only guard
// rather than guessing a first payment from the event: the trial's sync grants nothing, the
// renewal that ends the trial grants it, and an account subscribed before the grant existed
// gets it on its next launch.
const welcomeIfPaid = async (userId: UserId, entitlement: Entitlement) => {
  if (earnsPremiumWelcome(entitlement, new Date())) await QuotaCommand.grantPremiumWelcome(userId)
}

// Record what the App Store sold and hand the Premium welcome when it is earned.
const recordAndWelcome = async (userId: UserId, transaction: SubscriptionTransaction) => {
  const entitlement = await EntitlementCommand.record(userId, transaction)
  await welcomeIfPaid(userId, entitlement)
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
    await welcomeIfPaid(userId, entitlement)
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

  // Whether the caller is a TestFlight tester, asked of App Store Connect when the account
  // holds no store subscription and the last answer is a day old or absent: a tester signing
  // in is Premium on their first request, one removed loses it within a day, and a subscriber
  // costs nothing. Free calls only (App Store Connect, the email the sign-in token carries).
  // An account signed in through Apple's email relay cannot match; the comp list covers it.
  // App Store Connect failing leaves the last answer standing, and is reported.
  export const checkTestFlightTester = async (
    userId: UserId,
    email: string | undefined,
    now = new Date(),
  ): Promise<void> => {
    if (!email || (await EntitlementQuery.holdsStorePremium(userId))) return
    const grant = await EntitlementQuery.grantOf(userId)
    if (!needsTesterCheck(grant, now)) return

    let emails: string[] | undefined
    try {
      emails = await AppStoreConnect.testerEmails()
    } catch (error) {
      logger.warn('testflight tester check failed', { error, userId })
      return
    }
    if (!emails) return
    const isTester = emails.map(normalizedEmail).includes(normalizedEmail(email))
    await EntitlementCommand.recordTesterCheck(userId, isTester, now, grant)
    if (isTester !== (grant?.active ?? false)) {
      logger.info('testflight tester grant changed', { userId, isTester })
    }
  }
}
