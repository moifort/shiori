import { AdminCommand } from '~/domain/admin/command'
import { EntitlementQuery } from '~/domain/entitlement/query'
import { exhausted } from '~/domain/quota/business-rules'
import { QuotaCommand } from '~/domain/quota/command'
import { QuotaQuery } from '~/domain/quota/query'
import { Scan } from '~/domain/scan'
import { imageWithinSizeLimit } from '~/domain/scan/limits'
import { pageTitleOf } from '~/domain/scan/page-title'
import { builder } from '~/domain/shared/graphql/builder'
import { domainError } from '~/domain/shared/graphql/errors'
import { languageFrom } from '~/domain/shared/language'
import { BookTitle } from '~/domain/shared/primitives'
import { createLogger } from '~/system/logger'
import { ScanResultType } from './types'

const logger = createLogger('scan')

builder.mutationField('scanLink', (t) =>
  t.field({
    type: ScanResultType,
    description:
      'Look a book up from a page the reader shared — a bookshop, a review, a ' +
      'library catalogue — and return a record to review.\n\n' +
      "The page is fetched for its title, the shop's own name and the format " +
      'stripped off it, and the rest goes through the same lookup a typed title ' +
      'does. A page that does not answer, is not a page, or has no title falls ' +
      'back to `recognized: false` rather than failing: a shared link is a ' +
      'convenience, not a contract.\n\n' +
      'Spends one scan of the allowance, and only when the title was found — a ' +
      'link that led nowhere costs the reader nothing.',
    args: {
      url: t.arg.string({ required: true, description: 'The page that was shared' }),
    },
    resolve: async (_root, { url }, { userId, event }) => {
      const [plan, quota, credit] = await Promise.all([
        EntitlementQuery.planOf(userId),
        QuotaQuery.ofCurrentMonth(userId),
        QuotaQuery.creditOf(userId),
      ])
      if (exhausted(plan, quota, credit))
        return domainError('QUOTA_EXHAUSTED', 'Scan allowance is used up')

      const title = await pageTitleOf(url)
      if (!title) return { recognized: false, title: '' as const, authors: [], subgenres: [] }

      const language = languageFrom(event && getHeader(event, 'accept-language'))
      try {
        const { result, usage } = await Scan.lookUpTitle(BookTitle(title), language)
        await QuotaCommand.record(userId, plan)
        await AdminCommand.recordAiUsage({ cacheHit: false, usage }).catch((error) =>
          logger.warn('AI usage not recorded', { error }),
        )
        return result
      } catch (error) {
        // The reader is told the scan failed; we are told why.
        logger.error('shared link lookup failed', { error, userId })
        const message = error instanceof Error ? error.message : 'Lookup failed'
        return domainError('SCAN_FAILED', message)
      }
    },
  }),
)

builder.mutationField('scanTitle', (t) =>
  t.field({
    type: ScanResultType,
    description:
      'Look a book up from a title the reader typed and return a record to review, ' +
      'as `scanBook` does from a cover.\n\n' +
      'The title can be approximate: the model looks for the most likely book and ' +
      'answers with its exact title. Nothing is saved; the reader corrects the ' +
      'proposal and `addBook` persists it.\n\n' +
      'Two model calls at most — the web-grounded enrichment, and a series ' +
      'catalogue only when the saga is not already known. Never cached, and always ' +
      'spends one scan of the allowance. Fails with `QUOTA_EXHAUSTED` once nothing ' +
      'is left, or `SCAN_FAILED` when the model call errors.',
    args: {
      title: t.arg({ type: 'BookTitle', required: true, description: 'The title as remembered' }),
    },
    resolve: async (_root, { title }, { userId, event }) => {
      const [plan, quota, credit] = await Promise.all([
        EntitlementQuery.planOf(userId),
        QuotaQuery.ofCurrentMonth(userId),
        QuotaQuery.creditOf(userId),
      ])
      if (exhausted(plan, quota, credit))
        return domainError('QUOTA_EXHAUSTED', 'Scan allowance is used up')

      const language = languageFrom(event && getHeader(event, 'accept-language'))

      try {
        const { result, usage } = await Scan.lookUpTitle(title, language)
        await QuotaCommand.record(userId, plan)
        await AdminCommand.recordAiUsage({ cacheHit: false, usage }).catch((error) =>
          logger.warn('AI usage not recorded', { error }),
        )
        return result
      } catch (error) {
        // The reader is told the scan failed; we are told why.
        logger.error('title lookup failed', { error, userId })
        const message = error instanceof Error ? error.message : 'Lookup failed'
        return domainError('SCAN_FAILED', message)
      }
    },
  }),
)

builder.mutationField('scanBook', (t) =>
  t.field({
    type: ScanResultType,
    description:
      'Read a book cover with AI and return a record for the reader to review.\n\n' +
      'Nothing is saved: the answer is a proposal. The app shows it, the reader ' +
      'corrects what the model got wrong, and `addBook` persists the result. That ' +
      'review step is the safety net against a misread cover.\n\n' +
      'Three model calls at most — the cover, a web-grounded enrichment, and a ' +
      'series catalogue only when the saga is not already known. Results are ' +
      'cached by SHA-256 and language, so scanning the same cover twice calls ' +
      'nothing.\n\n' +
      'Spends one scan of the allowance (see the `quota` query): the month first, ' +
      'then the scans granted at onboarding. Only a real model call is charged — ' +
      'a cached cover is free, and so is a failure. Fails with `QUOTA_EXHAUSTED` ' +
      'once nothing is left, `IMAGE_TOO_LARGE` above the 10 MB limit, or ' +
      '`SCAN_FAILED` when the model call errors.',
    args: {
      imageBase64: t.arg.string({
        required: true,
        description: 'Cover photo as a base64-encoded JPEG (no data URL prefix), up to 10 MB',
      }),
    },
    resolve: async (_root, { imageBase64 }, { userId, event }) => {
      if (!imageWithinSizeLimit(imageBase64.length))
        return domainError('IMAGE_TOO_LARGE', 'Image exceeds the 10 MB size limit')

      const [plan, quota, credit] = await Promise.all([
        EntitlementQuery.planOf(userId),
        QuotaQuery.ofCurrentMonth(userId),
        QuotaQuery.creditOf(userId),
      ])
      if (exhausted(plan, quota, credit))
        return domainError('QUOTA_EXHAUSTED', 'Scan allowance is used up')

      // The model writes its free text in the caller's language, and the header
      // also partitions the cache so two languages never cross-contaminate.
      const language = languageFrom(event && getHeader(event, 'accept-language'))

      try {
        const { result, cacheHit, usage } = await Scan.scanWithCache(
          Buffer.from(imageBase64, 'base64'),
          language,
        )
        // Metered after the fact, and only on a real model call: a Gemini failure
        // must not cost the reader a scan, and a cache hit costs us nothing.
        if (!cacheHit) await QuotaCommand.record(userId, plan)
        // What the call cost us, for the admin screen. Pure telemetry: the scan
        // already succeeded, so a failed counter write is logged and swallowed
        // rather than turned into an error the reader has to read.
        await AdminCommand.recordAiUsage({ cacheHit, usage }).catch((error) =>
          logger.warn('AI usage not recorded', { error }),
        )
        return result
      } catch (error) {
        // The reader is told the scan failed; we are told why.
        logger.error('cover scan failed', { error, userId })
        const message = error instanceof Error ? error.message : 'Scan failed'
        return domainError('SCAN_FAILED', message)
      }
    },
  }),
)
