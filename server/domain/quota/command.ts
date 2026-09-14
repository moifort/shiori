import type { WriteBatch } from 'firebase-admin/firestore'
import { match } from 'ts-pattern'
import {
  consumed,
  consumedCredit,
  debitFor,
  monthOf,
  welcomeCredit,
} from '~/domain/quota/business-rules'
import * as repository from '~/domain/quota/infrastructure/repository'
import type { ScanCredit, ScanDebit } from '~/domain/quota/types'
import type { Plan, UserId } from '~/domain/shared/types'

export namespace QuotaCommand {
  // Write down one scan that actually happened, against whichever counter owes
  // it. Called AFTER Gemini answered, never before: a failed scan must not cost
  // anyone a quota, and a refused request never reaches this point. Each counter
  // increments in its own transaction — two scans finishing together must count
  // two, and a plain read-then-set counted one.
  //
  // Returns what was debited, so the caller can tell a spent month from a spent
  // grant without reading the counters back.
  export const record = async (userId: UserId, plan: Plan): Promise<ScanDebit> => {
    const [quota, credit] = await Promise.all([
      repository.findBy(userId, monthOf(new Date())),
      repository.findCredit(userId),
    ])
    const debit = debitFor(plan, quota, credit)
    return (
      match(debit)
        .with({ on: 'monthly' }, async (debit) => {
          await repository.consume(userId, monthOf(new Date()), consumed)
          return debit
        })
        .with({ on: 'credit' }, async (debit) => {
          await repository.consumeCredit(userId, consumedCredit)
          return debit
        })
        // Nothing left to debit. Unreachable through the scan gate, which refuses
        // the request first; recorded as a no-op rather than an error so a race
        // between two last scans never fails the one that already got its answer.
        .with({ on: 'nothing' }, async (debit) => debit)
        .exhaustive()
    )
  }

  // Hand a brand-new account the scans it needs to stock its cellar. Called once,
  // from the onboarding that creates the profile, in that same batch.
  export const grantWelcomeCredit = (userId: UserId, batch?: WriteBatch): Promise<ScanCredit> =>
    repository.saveCredit(welcomeCredit(userId), batch)

  // Erase the account's monthly scan counters and its granted balance (account
  // deletion).
  export const deleteAllForUser = async (userId: UserId) => {
    await repository.removeAllByUser(userId)
  }
}
