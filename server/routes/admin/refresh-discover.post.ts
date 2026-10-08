import { AwaitedEditionUseCase } from '~/domain/awaited-edition/use-case'
import { AwardUseCase } from '~/domain/award/use-case'
import { DiscoveryUseCase } from '~/domain/discovery/use-case'

/** The hourly Découvrir pass, called by Cloud Scheduler: first every edition a
 *  reader awaits whose watch is never looked up or a week old, then every
 *  reader's sagas worked out again once a day, then every saga anybody follows
 *  looked up on the web once a week, the ones never looked up first, until the
 *  budget is spent — one budget for both, from the start of the run. What is
 *  found is written into the sagas' catalogues. Last, the award winners of the
 *  genres somebody looked at, with what is left of the run.
 *
 *  Always answers 200 with the counts, like the Audible sync: one failure is
 *  logged, and a retry would re-run everybody for it. */
export default defineEventHandler(async () => {
  const now = new Date()
  const startedAt = Date.now()
  const editions = await AwaitedEditionUseCase.watchDue(now, undefined, startedAt)
  const sagas = await DiscoveryUseCase.watchDueSagas(now, undefined, startedAt)
  const awards = await AwardUseCase.watchDue(now, undefined, startedAt)
  return { ...sagas, editions, awards }
})
