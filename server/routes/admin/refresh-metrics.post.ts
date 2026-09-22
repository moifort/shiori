import { AdminUseCase } from '~/domain/admin/use-case'

/** Refreshes the admin metrics projection (accounts, subscribers, App Store
 *  revenue, GCP bill), called daily by Cloud Scheduler.
 *
 *  Admin-token gated like every `/admin/` route, and idempotent: the refresh
 *  recomputes the whole projection from source, so a retried run overwrites it
 *  with the same figures rather than adding to anything. */
export default defineEventHandler(async () => {
  const projection = await AdminUseCase.refreshMetrics()
  return { status: 200, data: projection }
})
