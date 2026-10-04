import { freshStep, monthCostsView, monthOf, searchesOf } from '~/domain/admin/business-rules'
import * as repository from '~/domain/admin/infrastructure/repository'
import type { AdminMetricsProjection, AdminMetricsView } from '~/domain/admin/types'
import { Count } from '~/domain/shared/primitives'

export namespace AdminQuery {
  // Everything the admin screen shows: the daily projection joined with the
  // current month's live AI counters. Two document reads. Works before the
  // first scheduler run too — the projection sections just read as zeros and
  // nulls. A projection written in an earlier month (the 1st, before the
  // morning refresh) serves its totals but none of its month figures.
  export const metrics = async (): Promise<AdminMetricsView> => {
    const month = monthOf(new Date())
    const [usage, projection] = await Promise.all([
      repository.findUsage(month),
      repository.findProjection(),
    ])
    const thisMonth = projection && monthOf(projection.refreshedAt) === month
    const costs = projection?.costs?.month === month ? projection.costs : undefined
    const sessions = projection?.sessions?.month === month ? projection.sessions : undefined
    return {
      costs: costs ? monthCostsView(costs) : undefined,
      sessions: sessions?.days,
      totalUsers: projection?.totalUsers ?? Count(0),
      newUsers: (thisMonth && projection.newUsers) || Count(0),
      premium: projection?.premium ?? { total: Count(0), monthly: Count(0), yearly: Count(0) },
      newPremium: (thisMonth && projection.newPremium) || Count(0),
      revenue: projection?.revenue,
      scans: usage.scans,
      cacheHits: usage.cacheHits,
      searches: searchesOf(usage),
      vision: usage.vision,
      enrichment: usage.enrichment,
      catalogue: usage.catalogue,
      discovery: usage.discovery ?? freshStep(),
      refreshedAt: projection?.refreshedAt,
    }
  }

  /** The projection the last daily refresh stored, if any. */
  export const projection = (): Promise<AdminMetricsProjection | undefined> =>
    repository.findProjection()
}
