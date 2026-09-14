import * as repository from '~/domain/entitlement/infrastructure/repository'
import { AppAccountToken, OriginalTransactionId, ProductId } from '~/domain/entitlement/primitives'
import type { Entitlement } from '~/domain/entitlement/types'
import type { UserId } from '~/domain/shared/types'
import type { AppleTransaction } from '~/system/apple/types'

export namespace EntitlementCommand {
  // Write down what the App Store sold, from a transaction whose signature has
  // already been checked. Overwrites in place: a renewal is the same entitlement
  // with a later date, not a second one.
  export const record = async (
    userId: UserId,
    transaction: AppleTransaction & { expiresAt: Date; appAccountToken: string },
  ): Promise<Entitlement> =>
    repository.save({
      userId,
      productId: ProductId(transaction.productId),
      originalTransactionId: OriginalTransactionId(transaction.originalTransactionId),
      appAccountToken: AppAccountToken(transaction.appAccountToken),
      expiresAt: transaction.expiresAt,
      ...(transaction.revokedAt ? { revokedAt: transaction.revokedAt } : {}),
      updatedAt: new Date(),
    })

  // Forget the account's stored entitlement (account deletion). Removes only our
  // record: the App Store subscription keeps its own lifecycle and must be
  // cancelled in the App Store, which the app tells the user before deleting.
  export const deleteForUser = async (userId: UserId) => {
    await repository.remove(userId)
  }
}
