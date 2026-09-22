import { AdminCommand } from '~/domain/admin/command'
import { exhausted } from '~/domain/quota/business-rules'
import { QuotaCommand } from '~/domain/quota/command'
import { QuotaQuery } from '~/domain/quota/query'
import { ScanCommand } from '~/domain/scan/command'
import { pageTitleOf } from '~/domain/scan/page-title'
import type { ScanLanguage, ScanResult, ScanUsage } from '~/domain/scan/types'
import { BookTitle } from '~/domain/shared/primitives'
import type { BookTitle as BookTitleValue, Plan, UserId } from '~/domain/shared/types'
import { createLogger } from '~/system/logger'

const logger = createLogger('scan')

/** What a metered scan answers: the record to review, or why there is none. */
export type ScanOutcome = ScanResult | 'quota-exhausted' | { failed: string }

/** Every way a reader asks the model for a book — a cover, a typed title, a
 *  shared link — metered the same way: the allowance is checked before the
 *  model is called, spent only once it answered, and what the call cost us is
 *  recorded for the admin screen. One path, so no entry point can forget a step. */
export namespace ScanUseCase {
  /** Read a cover. A cover already scanned is served from the cache and spends
   *  nothing; a model failure spends nothing either. */
  export const scanCover = (userId: UserId, image: Buffer, language: ScanLanguage) =>
    metered(userId, 'cover scan failed', async () => ScanCommand.scanWithCache(image, language))

  /** Look a book up from a title the reader typed. Never cached, so it always
   *  spends one scan. */
  export const lookUpTitle = (userId: UserId, title: BookTitleValue, language: ScanLanguage) =>
    metered(userId, 'title lookup failed', async () => ({
      ...(await ScanCommand.lookUpTitle(title, language)),
      cacheHit: false,
    }))

  /** Look a book up from a page the reader shared. A page with no title falls
   *  back to an unrecognized result and costs nothing: a shared link is a
   *  convenience, not a contract. */
  export const lookUpLink = async (
    userId: UserId,
    url: string,
    language: ScanLanguage,
  ): Promise<ScanOutcome> => {
    if (await isExhausted(userId)) return 'quota-exhausted'
    const title = await pageTitleOf(url)
    if (!title) return { recognized: false, title: '', authors: [], subgenres: [] }
    return lookUpTitle(userId, BookTitle(title), language)
  }
}

const planIfAllowed = async (userId: UserId): Promise<Plan | undefined> => {
  const { plan, quota, credit } = await QuotaQuery.allowanceOf(userId)
  return exhausted(plan, quota, credit) ? undefined : plan
}

// The reads are memoized for the request, so checking twice — once before a
// link is fetched, once before the model is called — costs one set of reads.
const isExhausted = async (userId: UserId) => (await planIfAllowed(userId)) === undefined

const metered = async (
  userId: UserId,
  failure: string,
  scan: () => Promise<{ result: ScanResult; cacheHit: boolean; usage: ScanUsage }>,
): Promise<ScanOutcome> => {
  const plan = await planIfAllowed(userId)
  if (!plan) return 'quota-exhausted'
  try {
    const { result, cacheHit, usage } = await scan()
    // Metered after the fact, and only on a real model call: a failure must
    // not cost the reader a scan, and a cache hit costs us nothing.
    if (!cacheHit) await QuotaCommand.record(userId, plan)
    // Pure telemetry: the scan already succeeded, so a failed counter write is
    // logged rather than turned into an error the reader has to read.
    await AdminCommand.recordAiUsage({ cacheHit, usage }).catch((error) =>
      logger.warn('AI usage not recorded', { error }),
    )
    return result
  } catch (error) {
    // The reader is told the scan failed; we are told why.
    logger.error(failure, { error, userId })
    return { failed: error instanceof Error ? error.message : 'Scan failed' }
  }
}
