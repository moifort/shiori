import { DiscoveryUseCase } from '~/domain/discovery/use-case'

/** The morning release alerts, called by Cloud Scheduler: every volume that
 *  came out, pushed to the readers who follow its saga. No model is called —
 *  the hourly pass already knows the dates — and a volume is pushed once, so a
 *  retry sends nothing twice. */
export default defineEventHandler(async () => DiscoveryUseCase.sendAlertsToEveryReader())
