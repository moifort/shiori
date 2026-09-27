import { AdminCommand } from '~/domain/admin/command'
import { shelfKeyOf } from '~/domain/book/business-rules'
import { BookQuery } from '~/domain/book/query'
import { exhausted } from '~/domain/quota/business-rules'
import { QuotaCommand } from '~/domain/quota/command'
import { QuotaQuery } from '~/domain/quota/query'
import { ScanCommand } from '~/domain/scan/command'
import { pageTitleOf } from '~/domain/scan/page-title'
import type {
  DetectedBook,
  ScanLanguage,
  ScanResult,
  ScanUsage,
  TitleCandidate,
} from '~/domain/scan/types'
import { BookTitle } from '~/domain/shared/primitives'
import type { BookTitle as BookTitleValue, Plan, UserId } from '~/domain/shared/types'
import { createLogger } from '~/system/logger'

const logger = createLogger('scan')

/** What a metered scan answers: the record to review, or why there is none. */
export type ScanOutcome = ScanResult | 'quota-exhausted' | { failed: string }

/** What a shelf photo answers: its books, or why there are none. */
export type ShelfOutcome =
  | DetectedBook[]
  | 'premium-required'
  | 'quota-exhausted'
  | { failed: string }

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

  /** Describe a book already named — a volume the release watch announced —
   *  for the reader to look at before adding it. Never cached, so it always
   *  spends one scan. */
  export const lookUpEdition = (userId: UserId, seen: ScanResult, language: ScanLanguage) =>
    metered(userId, 'edition lookup failed', async () => ({
      ...(await ScanCommand.lookUpEdition(seen, language)),
      cacheHit: false,
    }))

  /** The books a typed title may mean, for the reader to pick before
   *  `lookUpTitle` runs. Refused once the allowance is used up, like every call
   *  to the model, but spends nothing: the scan is the lookup that follows, and
   *  a reader choosing between three books still pays for one. */
  export const searchTitle = async (
    userId: UserId,
    title: BookTitleValue,
    language: ScanLanguage,
  ): Promise<TitleCandidate[] | 'quota-exhausted' | { failed: string }> => {
    if (await isExhausted(userId)) return 'quota-exhausted'
    try {
      const { candidates, usage } = await ScanCommand.findCandidates(title, language)
      if (usage)
        await AdminCommand.recordTitleSearchUsage(usage).catch((error) =>
          logger.warn('AI usage not recorded', { error }),
        )
      return candidates
    } catch (error) {
      logger.error('title search failed', { error, userId })
      return { failed: error instanceof Error ? error.message : 'Search failed' }
    }
  }

  /** The books of a shelf photo, each flagged when the reader already owns it.
   *  Premium only, and asked before anything else so a free reader is told
   *  what would open it rather than that they ran out. Spends nothing — every
   *  book kept is its own scan — but refused once the allowance is used up,
   *  since those scans would be. */
  export const detectBooks = async (
    userId: UserId,
    image: Buffer,
    language: ScanLanguage,
  ): Promise<ShelfOutcome> => {
    const { plan, quota, credit } = await QuotaQuery.allowanceOf(userId)
    if (plan !== 'premium') return 'premium-required'
    if (exhausted(plan, quota, credit)) return 'quota-exhausted'
    try {
      const [{ books, usage }, owned] = await Promise.all([
        ScanCommand.detectBooks(image, language),
        BookQuery.shelfKeys(userId),
      ])
      if (usage)
        await AdminCommand.recordShelfUsage(usage).catch((error) =>
          logger.warn('AI usage not recorded', { error }),
        )
      return books.map((book) => ({
        ...book,
        owned: book.title !== undefined && owned.has(shelfKeyOf(book.title, book.authors[0])),
      }))
    } catch (error) {
      logger.error('shelf detection failed', { error, userId })
      return { failed: error instanceof Error ? error.message : 'Detection failed' }
    }
  }

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
