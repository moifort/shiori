import type { AiStepUsage, AiUsage, PremiumBreakdown } from '~/domain/admin/types'
import { isActive } from '~/domain/entitlement/business-rules'
import type { Entitlement } from '~/domain/entitlement/types'
import { Count, Eur, Month } from '~/domain/shared/primitives'
import type { Count as CountType, Eur as EurType, Month as MonthType } from '~/domain/shared/types'

// What `gemini-3.5-flash-lite` costs per million tokens, the model every scan
// step calls (server/domain/scan/gemini.ts). Thinking tokens bill at the output
// rate, which is why they are counted apart from plain output.
//
// Flat, with no dated increase: this replaced a rate indexed on the month, which
// 3.6-flash needed because its introductory price doubles on January 1st 2027.
// Change the model there and these two numbers are what has to follow.
// https://ai.google.dev/gemini-api/docs/pricing
const INPUT_USD_PER_MILLION = 0.3
const OUTPUT_USD_PER_MILLION = 2.5

// Grounding is billed per search the model chose to run, not per call and not
// per token: $14 per thousand past the first 5,000 of the month. That allowance
// is shared across every Gemini 3.x model of the project, so anything else
// calling Gemini here eats into it and this figure reads low.
//
// Worth its own line because it is a different lever: past the allowance one
// grounded search costs more than all the tokens of the scan that ran it.
const FREE_SEARCHES_PER_MONTH = 5000
const USD_PER_THOUSAND_SEARCHES = 14

// A fixed conversion, not a live rate: the cost figure steers decisions, it does
// not close books. Revised by hand when the rate drifts far enough to matter.
const USD_TO_EUR = 0.91

// The month a moment belongs to, `"2026-09"`, also the ai-usage document id.
// UTC on purpose, mirroring the quota month: the window must not move with
// anyone's timezone.
export const monthOf = (moment: Date): MonthType =>
  Month(`${moment.getUTCFullYear()}-${String(moment.getUTCMonth() + 1).padStart(2, '0')}`)

// A month nothing has been spent in yet — what an absent ai-usage document means.
export const freshUsage = (month: MonthType): AiUsage => ({
  month,
  scans: Count(0),
  cacheHits: Count(0),
  vision: freshStep(),
  enrichment: freshStep(),
  catalogue: freshStep(),
  discovery: freshStep(),
})

export const freshStep = (): AiStepUsage => ({
  promptTokens: Count(0),
  outputTokens: Count(0),
  thinkingTokens: Count(0),
  searches: Count(0),
})

const stepsOf = (usage: AiUsage) => [
  usage.vision,
  usage.enrichment,
  usage.catalogue,
  usage.discovery ?? freshStep(),
]

// What the month's measured tokens cost in euros, every Gemini call combined.
export const tokenCostEur = (usage: AiUsage): EurType => {
  const steps = stepsOf(usage)
  const promptTokens = steps.reduce((sum, step) => sum + step.promptTokens, 0)
  const billedAsOutput = steps.reduce(
    (sum, step) => sum + step.outputTokens + step.thinkingTokens,
    0,
  )
  const usd =
    (promptTokens * INPUT_USD_PER_MILLION + billedAsOutput * OUTPUT_USD_PER_MILLION) / 1_000_000
  return Eur(usd * USD_TO_EUR)
}

// What the month's grounded searches cost in euros. Nothing until the monthly
// allowance is spent, then every further search is billed — so this reads zero
// for a long time and is not broken when it does.
export const searchCostEur = (usage: AiUsage): EurType => {
  const searches = stepsOf(usage).reduce((sum, step) => sum + step.searches, 0)
  const billable = Math.max(0, searches - FREE_SEARCHES_PER_MONTH)
  return Eur(((billable * USD_PER_THOUSAND_SEARCHES) / 1000) * USD_TO_EUR)
}

// How many searches the month ran, allowance included — what says how close the
// free 5,000 are to running out, which the cost alone cannot while it reads zero.
export const searchesOf = (usage: AiUsage): CountType =>
  Count(stepsOf(usage).reduce((sum, step) => sum + step.searches, 0))

// Everything Gemini bills for the month: the tokens and the searches.
export const aiCostEur = (usage: AiUsage): EurType =>
  Eur(tokenCostEur(usage) + searchCostEur(usage))

// Who is Premium right now, split by the billing period the product id names.
// `total` counts every active entitlement, so an unexpected product id still
// shows up there even if it lands in neither split.
export const premiumBreakdown = (entitlements: Entitlement[], now: Date): PremiumBreakdown => {
  const active = entitlements.filter((entitlement) => isActive(entitlement, now))
  const of = (suffix: string) =>
    Count(active.filter(({ productId }) => (productId as string).endsWith(suffix)).length)
  return { total: Count(active.length), monthly: of('.monthly'), yearly: of('.yearly') }
}
