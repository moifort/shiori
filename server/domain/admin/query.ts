import { aiCostEur, monthOf } from '~/domain/admin/business-rules'
import * as repository from '~/domain/admin/infrastructure/repository'
import type { AdminMetricsView } from '~/domain/admin/types'
import { Count, Eur } from '~/domain/shared/primitives'

export namespace AdminQuery {
  // Everything the admin screen shows: the daily projection joined with the
  // current month's live AI usage, priced in euros. Works before the first
  // scheduler run too — the projection sections just read as zeros and nulls.
  export const metrics = async (): Promise<AdminMetricsView> => {
    const month = monthOf(new Date())
    const [usage, projection] = await Promise.all([
      repository.findUsage(month),
      repository.findProjection(),
    ])
    const ai = aiCostEur(usage)
    // Infra is the measured GCP bill alone: absent until the export answers,
    // and it does not carry any fixed line (the Apple fee is shared with other
    // projects, so it is not this app's cost to show).
    const infra = projection?.infra?.gcpCostEur
    return {
      aiCostEur: ai,
      infraEur: infra,
      totalCostEur: Eur(ai + (infra ?? 0)),
      totalUsers: projection?.totalUsers ?? Count(0),
      premium: projection?.premium ?? { total: Count(0), monthly: Count(0), yearly: Count(0) },
      revenue: projection?.revenue,
      scans: usage.scans,
      cacheHits: usage.cacheHits,
      vision: usage.vision,
      enrichment: usage.enrichment,
      catalogue: usage.catalogue,
      refreshedAt: projection?.refreshedAt,
    }
  }
}
