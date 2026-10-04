import type { Count, Day, Eur, Month } from '~/domain/shared/types'

/** What one Gemini call consumed, as `usageMetadata` reported it. No longer
 *  priced: the cost is read from the bill. The counters stay because they say
 *  where the calls go, which the bill does not.
 *
 *  `searches` counts the Google searches a grounded step ran — the line the
 *  bill turns on once the monthly free allowance runs out. Only enrichment,
 *  catalogue and Découvrir can have any. */
export type AiStepUsage = {
  promptTokens: Count
  outputTokens: Count
  thinkingTokens: Count
  searches: Count
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
  /** The Découvrir tab's calls: suggestions, award lists and release dates.
   *  Absent on a month recorded before the tab existed. */
  discovery?: AiStepUsage
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

/** What the bill says one day cost, as the billing export reports it: the
 *  Gemini API on its own, every other service of the project as
 *  infrastructure. Credits (the free tier) are folded in. */
export type DailyCost = {
  day: Day
  geminiEur: Eur
  infraEur: Eur
}

/** How many sessions GA4 counted on one day. */
export type DailySessions = {
  day: Day
  sessions: Count
}

/** The month's bill so far, one entry per billed day, and last month's total
 *  when that month is one the export fully covers. */
export type MonthCosts = {
  month: Month
  days: DailyCost[]
  previousMonthEur?: Eur
}

export type MonthSessions = {
  month: Month
  days: DailySessions[]
}

/** The read model the daily refresh writes — a single `current` document.
 *  `revenue`, `costs` and `sessions` are absent until their external source has
 *  answered once (missing config, API refusal), and a later failed fetch keeps
 *  the last stored value of the same month rather than erasing it. `newUsers`
 *  and `newPremium` count the month the refresh ran in. */
export type AdminMetricsProjection = {
  totalUsers: Count
  newUsers: Count
  premium: PremiumBreakdown
  newPremium: Count
  revenue?: Revenue
  costs?: MonthCosts
  sessions?: MonthSessions
  refreshedAt: Date
}

/** The month's bill as the admin screen reads it. `billedThrough` is the last
 *  day the export has reached, about a day behind; the projection extends the
 *  daily average over those days to the whole month, and is absent while no day
 *  is billed yet. `changeVsPreviousMonth` is a ratio (`0.12` is 12 % more). */
export type MonthCostsView = {
  geminiEur: Eur
  infraEur: Eur
  totalEur: Eur
  projectedEur?: Eur
  previousMonthEur?: Eur
  changeVsPreviousMonth?: number
  billedThrough?: Day
  days: DailyCost[]
}

/** What the admin screen shows: the projection of the current month joined
 *  with its live AI counters. `costs` and `sessions` are absent while their
 *  source has not answered for this month; `refreshedAt` is absent until the
 *  daily refresh has run once. */
export type AdminMetricsView = {
  costs?: MonthCostsView
  sessions?: DailySessions[]
  totalUsers: Count
  newUsers: Count
  premium: PremiumBreakdown
  newPremium: Count
  revenue?: Revenue
  scans: Count
  cacheHits: Count
  /** Every grounded search of the month, as the counters measured them. */
  searches: Count
  vision: AiStepUsage
  enrichment: AiStepUsage
  catalogue: AiStepUsage
  discovery: AiStepUsage
  refreshedAt?: Date
}
