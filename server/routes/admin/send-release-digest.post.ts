import { DiscoveryUseCase } from '~/domain/discovery/use-case'

/** The Sunday digest, called by Cloud Scheduler: one notification per reader
 *  naming the volumes newly announced in the sagas they follow. No model is
 *  called, and a volume is named once, so a retry sends nothing twice. */
export default defineEventHandler(async () => DiscoveryUseCase.sendDigestToEveryReader())
