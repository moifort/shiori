import { DiscoveryUseCase } from '~/domain/discovery/use-case'

/** The hourly Découvrir pass, called by Cloud Scheduler: every reader's sagas
 *  worked out again once a day, then every saga anybody follows looked up on
 *  the web once a week, the ones never looked up first, until the budget is
 *  spent. What is found is written into the sagas' catalogues.
 *
 *  Always answers 200 with the counts, like the Audible sync: one failure is
 *  logged, and a retry would re-run everybody for it. */
export default defineEventHandler(async () => DiscoveryUseCase.watchDueSagas())
