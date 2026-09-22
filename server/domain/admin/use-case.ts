import { monthOf, premiumBreakdown } from '~/domain/admin/business-rules'
import { AdminCommand } from '~/domain/admin/command'
import { AdminQuery } from '~/domain/admin/query'
import type { AdminMetricsProjection, InfraUsage, Revenue } from '~/domain/admin/types'
import { EntitlementQuery } from '~/domain/entitlement/query'
import { Eur } from '~/domain/shared/primitives'
import type { Month } from '~/domain/shared/types'
import { UserQuery } from '~/domain/user/query'
import { AppStoreConnect } from '~/system/appstore-connect'
import { GcpBilling } from '~/system/gcp-billing'
import { createLogger } from '~/system/logger'

const logger = createLogger('admin')

export namespace AdminUseCase {
  // The daily job behind the admin screen: count the accounts, work out who is
  // Premium, ask Apple what the month sold and BigQuery what GCP billed, and
  // write it all as the `current` projection the GraphQL view reads.
  export const refreshMetrics = async (): Promise<AdminMetricsProjection> => {
    const now = new Date()
    const month = monthOf(now)
    const [totalUsers, entitlements, previous] = await Promise.all([
      UserQuery.total(),
      EntitlementQuery.all(),
      AdminQuery.projection(),
    ])
    // The two external sources are independent and both best-effort: missing
    // config or a failing API keeps the last stored figure rather than failing
    // the whole refresh or erasing what was known.
    const [revenue, infra] = await Promise.all([
      revenueOf(month, previous?.revenue),
      infraOf(month, previous?.infra),
    ])
    return AdminCommand.recordMetrics({
      totalUsers,
      premium: premiumBreakdown(entitlements, now),
      revenue,
      infra,
      refreshedAt: now,
    })
  }
}

const revenueOf = async (month: Month, last: Revenue | undefined) => {
  try {
    const sales = await AppStoreConnect.monthSales(month)
    if (!sales) return last
    return { month, proceedsEur: Eur(sales.proceedsEur), grossEur: Eur(sales.grossEur) }
  } catch (error) {
    logger.error('App Store revenue refresh failed, keeping the last figure', { error })
    return last
  }
}

const infraOf = async (month: Month, last: InfraUsage | undefined) => {
  try {
    const cost = await GcpBilling.monthCost(month)
    if (cost === undefined) return last
    return { month, gcpCostEur: Eur(cost) }
  } catch (error) {
    logger.error('GCP billing refresh failed, keeping the last figure', { error })
    return last
  }
}
