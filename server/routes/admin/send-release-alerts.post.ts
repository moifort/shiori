import { AwaitedEditionUseCase } from '~/domain/awaited-edition/use-case'
import { DiscoveryUseCase } from '~/domain/discovery/use-case'

/** The morning release alerts, called by Cloud Scheduler: every volume that
 *  came out, pushed to the readers who follow its saga, and every edition
 *  awaited that came out, pushed to the reader awaiting it. No model is called —
 *  the hourly pass already knows the dates — and each is pushed once, so a retry
 *  sends nothing twice. */
export default defineEventHandler(async () => {
  const sagas = await DiscoveryUseCase.sendAlertsToEveryReader()
  const editions = await AwaitedEditionUseCase.sendAlerts()
  return { ...sagas, editions }
})
