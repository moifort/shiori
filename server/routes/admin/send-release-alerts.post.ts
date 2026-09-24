import { DiscoverUseCase } from '~/domain/discover/use-case'

/** The daily translation alerts, called by Cloud Scheduler in the morning:
 *  what came out, pushed to whoever left the alert on. No model is called —
 *  the daily refresh already knows the dates — and an edition is pushed once,
 *  so a retry sends nothing twice. */
export default defineEventHandler(async () => DiscoverUseCase.sendAlertsToEveryReader())
