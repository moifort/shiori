import { AudibleUseCase } from '~/domain/audible/use-case'

/** The nightly Audible pass, called by Cloud Scheduler.
 *
 *  Admin-token gated like every `/admin/` route, and deliberately idempotent: a
 *  retried run re-reads Amazon and finds nothing new to do, because what makes a
 *  title new is a purchase date the last run already moved past.
 *
 *  Always answers 200. A reader whose sync failed is counted in the body and
 *  logged; failing the request would make the scheduler retry the whole
 *  population for one reader's revoked device. */
export default defineEventHandler(async () => AudibleUseCase.syncEveryReader())
