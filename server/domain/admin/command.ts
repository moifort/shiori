import { monthOf } from '~/domain/admin/business-rules'
import * as repository from '~/domain/admin/infrastructure/repository'
import type { AdminMetricsProjection } from '~/domain/admin/types'
import type { AiStepUsage, ScanUsage } from '~/domain/scan/types'

export namespace AdminCommand {
  // Fold one scan into the month's cost counters — a single atomic write of
  // increments, called by the scan use case after the fact. A cache hit counts
  // as a hit and no tokens; a real scan counts once with whatever the steps that
  // ran reported. The caller treats this as telemetry: a failure here must never
  // fail the scan that produced it.
  export const recordAiUsage = async (scan: { cacheHit: boolean; usage: ScanUsage }) => {
    await repository.recordUsage(monthOf(new Date()), {
      scans: scan.cacheHit ? 0 : 1,
      cacheHits: scan.cacheHit ? 1 : 0,
      vision: scan.usage.vision,
      enrichment: scan.usage.enrichment,
      catalogue: scan.usage.catalogue,
    })
  }

  // A catalogue built on its own — the series screen opening a saga an Audible
  // import named. No scan ran, so only the third step's line moves. Telemetry
  // like the above: the caller logs and swallows a failure.
  export const recordCatalogueUsage = async (catalogue: AiStepUsage) => {
    await repository.recordUsage(monthOf(new Date()), { scans: 0, cacheHits: 0, catalogue })
  }

  /** Store the daily projection the admin screen reads. A full set: the
   *  refresh recomputes everything, and a section that came back absent must
   *  disappear rather than linger. */
  export const recordMetrics = async (projection: AdminMetricsProjection) =>
    repository.saveProjection(projection)
}
