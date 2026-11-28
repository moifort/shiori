import type { WriteBatch } from 'firebase-admin/firestore'
import {
  consumed,
  consumedCredit,
  debitFor,
  monthOf,
  welcomeCredit,
  withPremiumWelcome,
} from '~/domain/quota/business-rules'
import * as repository from '~/domain/quota/infrastructure/repository'
import type { ScanCredit, ScanDebit } from '~/domain/quota/types'
import type { Plan, UserId } from '~/domain/shared/types'

export namespace QuotaCommand {
  // Write down one scan that actually happened, against whichever counter owes
  // it. Called AFTER Gemini answered, never before: a failed scan must not cost
  // anyone a quota, and a refused request never reaches this point. The counter is
  // chosen and spent in one transaction that reads both: two scans finishing
  // together count two, and the month's last scan is taken once — a choice made on
  // the reads from before the call let both take it and left the grant untouched.
  //
  // Returns what was debited, so the caller can tell a spent month from a spent
  // grant without reading the counters back. `nothing` is a no-op rather than an
  // error, so a race between two last scans never fails the one that already got its
  // answer: the overshoot is bounded by the scans in flight at the gate, each answered.
  export const record = async (userId: UserId, plan: Plan): Promise<ScanDebit> =>
    repository.spendOne(
      userId,
      monthOf(new Date()),
      (quota, credit) => debitFor(plan, quota, credit),
      consumed,
      consumedCredit,
    )

  // Hand a brand-new account the scans it needs for its first shelf. Called once,
  // from the onboarding that creates the profile, in that same batch.
  export const grantWelcomeCredit = (userId: UserId, batch?: WriteBatch): Promise<ScanCredit> =>
    repository.saveCredit(welcomeCredit(userId), batch)

  // Hand an account turning Premium the scans to bring its whole library in, on
  // top of what it holds. Safe to call on every sync: only the first lands.
  export const grantPremiumWelcome = (userId: UserId): Promise<ScanCredit> =>
    repository.topUpCredit(userId, (credit) => withPremiumWelcome(credit, new Date()))

  // Erase the account's monthly scan counters and its granted balance (account
  // deletion).
  export const deleteAllForUser = async (userId: UserId) => {
    await repository.removeAllByUser(userId)
  }
}
