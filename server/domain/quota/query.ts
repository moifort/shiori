import { EntitlementQuery } from '~/domain/entitlement/query'
import { monthOf } from '~/domain/quota/business-rules'
import * as repository from '~/domain/quota/infrastructure/repository'
import type { Quota, ScanCredit } from '~/domain/quota/types'
import type { Plan, UserId } from '~/domain/shared/types'

export namespace QuotaQuery {
  // What this account has spent in the month it is currently living in. Never
  // absent: a month nobody has touched reads back at zero.
  export const ofCurrentMonth = (userId: UserId): Promise<Quota> =>
    repository.findBy(userId, monthOf(new Date()))

  // The scans this account still holds outside the month. Never absent either:
  // an account that was never granted any reads back at zero.
  export const creditOf = (userId: UserId): Promise<ScanCredit> => repository.findCredit(userId)

  /** Everything a scan allowance is decided on: the plan, the month spent, the
   *  scans granted. What the scan gate checks and the `quota` query shows —
   *  memoized reads, so asking both in one request costs one set. */
  export const allowanceOf = async (
    userId: UserId,
  ): Promise<{ plan: Plan; quota: Quota; credit: ScanCredit }> => {
    const [plan, quota, credit] = await Promise.all([
      EntitlementQuery.planOf(userId),
      ofCurrentMonth(userId),
      creditOf(userId),
    ])
    return { plan, quota, credit }
  }
}
