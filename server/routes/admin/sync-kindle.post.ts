import { KindleUseCase } from '~/domain/kindle/use-case'

/** The nightly Kindle pass, called by Cloud Scheduler.
 *
 *  Admin-token gated like every `/admin/` route, and idempotent: a retried run
 *  re-reads Amazon and finds nothing new, because what makes a title new is an
 *  acquisition date the last run moved past, and what makes a read status news
 *  is an ASIN the last run did not see read.
 *
 *  Always answers 200. A reader whose pass failed is counted in the body and
 *  recorded on their connection; failing the request would make the scheduler
 *  re-run the whole population for one reader's deregistered device. */
export default defineEventHandler(async () => KindleUseCase.syncEveryReader())
