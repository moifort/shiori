import { DiscoverUseCase } from '~/domain/discover/use-case'

/** The daily release alerts, called by Cloud Scheduler in the morning: what
 *  came out today, pushed to whoever switched its alert on. No model is
 *  called — the weekly refresh already knows the dates — and a release is
 *  pushed once, so a retry sends nothing twice. */
export default defineEventHandler(async () => DiscoverUseCase.sendAlertsToEveryReader())
