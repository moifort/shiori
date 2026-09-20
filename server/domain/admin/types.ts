import type { Count, Eur, Month } from '~/domain/shared/types'

/** What one Gemini call consumed, as `usageMetadata` reported it. Thinking
 *  tokens are kept apart from plain output because they bill at the output rate
 *  and are the largest line on a scan. */
export type AiStepUsage = {
  promptTokens: Count
  outputTokens: Count
  thinkingTokens: Count
}

/** One month's measured AI consumption — a single document per month whose id
 *  IS the month key (`"2026-09"`), incremented in real time by the scan path.
 *  `scans` counts only the requests that really reached Gemini; a cache hit
 *  lands in `cacheHits` and adds no tokens.
 *
 *  The three steps are counted apart because they do not run together: every
 *  scan reads the cover, an unrecognized one stops there, and the catalogue call
 *  only happens for a saga nobody has scanned before. Folded into one total, a
 *  cheap month and a month of first-time sagas would look alike. */
export type AiUsage = {
  month: Month
  scans: Count
  cacheHits: Count
  vision: AiStepUsage
  enrichment: AiStepUsage
  catalogue: AiStepUsage
}

/** Active subscribers right now, split by the billing period their product id
 *  carries. */
export type PremiumBreakdown = {
  total: Count
  monthly: Count
  yearly: Count
}

/** What the App Store sold over one month: `grossEur` is what customers paid,
 *  `proceedsEur` what Apple pays out after its commission. */
export type Revenue = {
  month: Month
  proceedsEur: Eur
  grossEur: Eur
}

/** What GCP billed for one month, measured from the billing export. */
export type InfraUsage = {
  month: Month
  gcpCostEur: Eur
}

/** The read model the daily refresh writes — a single `current` document.
 *  `revenue` and `infra` are absent until their external source has answered
 *  once (missing config, API refusal), and a later failed fetch keeps the last
 *  stored value rather than erasing it. */
export type AdminMetricsProjection = {
  totalUsers: Count
  premium: PremiumBreakdown
  revenue?: Revenue
  infra?: InfraUsage
  refreshedAt: Date
}

/** What the admin screen shows: the projection joined with the current month's
 *  live AI usage and priced in euros. `infraEur` is the measured GCP bill for
 *  this project, absent until the billing export is configured and has answered
 *  (the Apple Developer fee is deliberately excluded: it is shared across
 *  several projects, so imputing it here would overstate this app's cost).
 *  `refreshedAt` is absent until the daily refresh has run once. */
export type AdminMetricsView = {
  aiCostEur: Eur
  infraEur?: Eur
  totalCostEur: Eur
  totalUsers: Count
  premium: PremiumBreakdown
  revenue?: Revenue
  scans: Count
  cacheHits: Count
  vision: AiStepUsage
  enrichment: AiStepUsage
  catalogue: AiStepUsage
  refreshedAt?: Date
}
