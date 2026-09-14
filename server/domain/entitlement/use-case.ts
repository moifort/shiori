import { EntitlementCommand } from '~/domain/entitlement/command'
import { AppAccountToken } from '~/domain/entitlement/primitives'
import { EntitlementQuery } from '~/domain/entitlement/query'
import type { Entitlement } from '~/domain/entitlement/types'
import type { UserId } from '~/domain/shared/types'
import { Apple } from '~/system/apple'
import type { AppleTransaction } from '~/system/apple/types'

// A transaction we can act on: signed by Apple, naming an account, and granting
// time (a one-off purchase would carry no expiry — there is none in this app, but
// the wire cannot promise that).
type SubscriptionTransaction = AppleTransaction & { expiresAt: Date; appAccountToken: string }

const grantsTime = (transaction: AppleTransaction): transaction is SubscriptionTransaction =>
  transaction.expiresAt !== undefined && transaction.appAccountToken !== undefined

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

    return EntitlementCommand.record(userId, transaction)
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

    await EntitlementCommand.record(known.userId, transaction)
    return 'applied'
  }
}
