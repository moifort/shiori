import { reconciled } from '~/domain/entitlement/business-rules'
import * as repository from '~/domain/entitlement/infrastructure/repository'
import { AppAccountToken, OriginalTransactionId, ProductId } from '~/domain/entitlement/primitives'
import type { Entitlement, PremiumGrant } from '~/domain/entitlement/types'
import type { UserId } from '~/domain/shared/types'
import type { AppleTransaction } from '~/system/apple/types'
import type { PlaySubscription } from '~/system/google-play/types'

export namespace EntitlementCommand {
  // Write down what the App Store sold, from a transaction whose signature has
  // already been checked. Overwrites the account's App Store entitlement in place: a renewal
  // is the same entitlement with a later date, not a second one. A transaction signed before
  // the one stored changes nothing, and a refund stays (`reconciled`). Answers what is now
  // recorded.
  export const record = async (
    userId: UserId,
    transaction: AppleTransaction & { expiresAt: Date; appAccountToken: string },
  ): Promise<Entitlement> =>
    repository.saveReconciled(
      {
        userId,
        productId: ProductId(transaction.productId),
        originalTransactionId: OriginalTransactionId(transaction.originalTransactionId),
        appAccountToken: AppAccountToken(transaction.appAccountToken),
        expiresAt: transaction.expiresAt,
        ...(transaction.revokedAt ? { revokedAt: transaction.revokedAt } : {}),
        ...(transaction.startedAt ? { startedAt: transaction.startedAt } : {}),
        ...(transaction.freeTrial ? { freeTrial: true } : {}),
        ...(transaction.sandbox ? { sandbox: true } : {}),
        ...(transaction.signedAt ? { signedAt: transaction.signedAt } : {}),
        updatedAt: new Date(),
      },
      reconciled,
    )

  // Write down what Google Play sold, from a purchase Google has already vouched for, in the
  // account's Play entitlement, beside any App Store one. The purchase token names the chain,
  // as Apple's original transaction id does.
  export const recordPlay = async (
    userId: UserId,
    subscription: PlaySubscription & { expiresAt: Date; accountToken: string },
  ): Promise<Entitlement> =>
    repository.saveReconciled(
      {
        userId,
        productId: ProductId(subscription.productId),
        originalTransactionId: OriginalTransactionId(subscription.purchaseToken),
        appAccountToken: AppAccountToken(subscription.accountToken),
        expiresAt: subscription.expiresAt,
        ...(subscription.revokedAt ? { revokedAt: subscription.revokedAt } : {}),
        ...(subscription.startedAt ? { startedAt: subscription.startedAt } : {}),
        ...(subscription.freeTrial ? { freeTrial: true } : {}),
        ...(subscription.sandbox ? { sandbox: true } : {}),
        signedAt: subscription.signedAt,
        updatedAt: new Date(),
        store: 'google-play',
      },
      reconciled,
    )

  // Forget the account's stored entitlements, every store's (account deletion). Removes only our
  // record: the App Store subscription keeps its own lifecycle and must be
  // cancelled in the App Store, which the app tells the user before deleting.
  export const deleteForUser = async (userId: UserId) => {
    await Promise.all([repository.removeAll(userId), repository.removeGrant(userId)])
  }

  // Write down what App Store Connect answered: Premium while the account is a tester, with
  // the day it became one kept across checks, and the answer's time either way.
  export const recordTesterCheck = async (
    userId: UserId,
    isTester: boolean,
    now: Date,
    previous: PremiumGrant | undefined,
  ): Promise<PremiumGrant> =>
    repository.saveGrant({
      userId,
      source: 'testflight',
      active: isTester,
      checkedAt: now,
      ...(isTester ? { grantedAt: previous?.active ? (previous.grantedAt ?? now) : now } : {}),
    })
}
