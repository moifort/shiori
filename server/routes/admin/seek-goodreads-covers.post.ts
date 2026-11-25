import { GoodreadsUseCase } from '~/domain/goodreads/use-case'

/** The Goodreads cover pass, called by Cloud Scheduler every quarter of an
 *  hour: the covers of an imported library keep coming once the app is closed.
 *
 *  Admin-token gated like every `/admin/` route, and idempotent: a book whose
 *  cover was sought has left the list, so a retried run picks up where the last
 *  one stopped. Always answers 200 with the counts; one reader's failure is
 *  logged and stepped over. */
export default defineEventHandler(async () => GoodreadsUseCase.seekEveryReadersCovers())
