import { AwardUseCase } from '~/domain/award/use-case'

/** The daily award pass, called by Cloud Scheduler: the winners of every
 *  ceremony after the latest one known, read off Wikidata. No model is called.
 *  Always answers 200 with the counts: an award Wikidata fails on is logged and
 *  asked again the next day. */
export default defineEventHandler(() => AwardUseCase.watchWinners())
