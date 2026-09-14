import { coverPrefixOf } from '~/domain/book/business-rules'
import { BookCommand } from '~/domain/book/command'
import { EntitlementCommand } from '~/domain/entitlement/command'
import { QuotaCommand } from '~/domain/quota/command'
import type { PersonName, UserId } from '~/domain/shared/types'
import { UserCommand } from '~/domain/user/command'
import { UserQuery } from '~/domain/user/query'
import { objectStore } from '~/system/object-store'
import { atomically } from '~/utils/firestore'

export namespace UserUseCase {
  // Finish onboarding: persist the profile and the scans the account starts
  // with, in one batch, so a partial failure never leaves a user "half
  // onboarded" — either all of it lands or none of it does.
  //
  // The welcome scans are granted only the FIRST time, on an account with no
  // profile yet. The mutation stays reachable afterwards (a reader changing the
  // name they are addressed by), and re-granting there would turn a one-off gift
  // into a renewable one. The read is the one the auth gate already did,
  // memoized, so it costs nothing.
  export const completeOnboarding = async (userId: UserId, input: { firstName: PersonName }) => {
    const firstTime = (await UserQuery.me(userId)).onboardingCompletedAt === undefined
    return atomically(async (batch) => {
      if (firstTime) await QuotaCommand.grantWelcomeCredit(userId, batch)
      return UserCommand.completeOnboarding(userId, input.firstName, batch)
    })
  }

  // Delete the account and every trace of it. Each step reaches a domain through
  // its public Command surface, never a repository — the domains own their
  // storage. The whole thing is idempotent, so a retry after a partial failure is
  // safe, and the order matters:
  //  1. Wipe every per-user collection in parallel; they are independent. This
  //     forgets our entitlement record but does NOT cancel the App Store
  //     subscription — Apple owns that lifecycle, and the app says so.
  //  2. Delete the cover images, which live in the bucket rather than Firestore
  //     and would otherwise survive the account that paid to scan them.
  //  3. Drop the profile.
  //  4. Delete the Firebase Auth user LAST: if an earlier step fails the reader
  //     is still signed in and can retry, whereas deleting auth first would
  //     strand the data with nobody able to reach it.
  //
  // The series catalogue is deliberately untouched. It holds no reference to any
  // reader and serves everyone, so erasing one account's books must not erase a
  // saga that other readers are following.
  export const deleteAccount = async (userId: UserId) => {
    await Promise.all([
      BookCommand.deleteAllForUser(userId),
      EntitlementCommand.deleteForUser(userId),
      QuotaCommand.deleteAllForUser(userId),
    ])
    await objectStore().removeByPrefix(coverPrefixOf(userId))
    await UserCommand.deleteProfile(userId)
    await UserCommand.deleteAuthAccount(userId)
  }
}
