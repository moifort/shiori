import { SuggestionUseCase } from '~/domain/suggestion/use-case'

/** The first of the month's discoveries pass, called by Cloud Scheduler: the
 *  month's selection made for a few readers who had one before, each told
 *  once it is. Always answers 200 with the counts: a reader whose generation
 *  failed is logged, and the next run takes the others. */
export default defineEventHandler(async () => SuggestionUseCase.generateForEveryReader())
