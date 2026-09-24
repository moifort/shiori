import { DiscoverUseCase } from '~/domain/discover/use-case'

/** The hourly Découvrir pass, called by Cloud Scheduler: every reader whose
 *  tab is a day old is refreshed, the oldest first, until the budget is
 *  spent. Only readers who opened the tab once are ever refreshed.
 *
 *  Always answers 200 with the counts, like the Audible sync: one reader's
 *  failure is logged, and a retry would re-run everybody for it. */
export default defineEventHandler(async () => DiscoverUseCase.refreshDueReaders())
