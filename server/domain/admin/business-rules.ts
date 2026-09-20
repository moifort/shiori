import type { AiStepUsage, AiUsage, PremiumBreakdown } from '~/domain/admin/types'
import { isActive } from '~/domain/entitlement/business-rules'
import type { Entitlement } from '~/domain/entitlement/types'
import { Count, Eur, Month } from '~/domain/shared/primitives'
import type { Eur as EurType, Month as MonthType } from '~/domain/shared/types'

// What `gemini-3.6-flash` costs per million tokens, the model every scan step
// calls (server/domain/scan/gemini.ts). Thinking tokens bill at the output rate,
// which is why they are counted apart from plain output.
//
// The introductory rate runs to the end of 2026 and doubles on January 1st 2027.
// Published and dated, so the month being priced picks its own rate rather than
// one constant going quietly wrong overnight — and a month already spent keeps
// the price it was really billed at, however late it is read back.
// https://ai.google.dev/gemini-api/docs/pricing
const INTRODUCTORY_RATE = { inputUsd: 0.75, outputUsd: 3.75 }
const STANDARD_RATE = { inputUsd: 1.5, outputUsd: 7.5 }
const STANDARD_RATE_FROM = Month('2027-01')

// Month keys are `YYYY-MM`, so comparing them as strings orders them by date.
const rateFor = (month: MonthType) =>
  month >= STANDARD_RATE_FROM ? STANDARD_RATE : INTRODUCTORY_RATE

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
})

const freshStep = (): AiStepUsage => ({
  promptTokens: Count(0),
  outputTokens: Count(0),
  thinkingTokens: Count(0),
})

// What the month's measured tokens cost in euros, every Gemini call combined,
// at the rate that month was billed at.
export const aiCostEur = (usage: AiUsage): EurType => {
  const { inputUsd, outputUsd } = rateFor(usage.month)
  const steps = [usage.vision, usage.enrichment, usage.catalogue]
  const promptTokens = steps.reduce((sum, step) => sum + step.promptTokens, 0)
  const billedAsOutput = steps.reduce(
    (sum, step) => sum + step.outputTokens + step.thinkingTokens,
    0,
  )
  const usd = (promptTokens * inputUsd + billedAsOutput * outputUsd) / 1_000_000
  return Eur(usd * USD_TO_EUR)
}

// Who is Premium right now, split by the billing period the product id names.
// `total` counts every active entitlement, so an unexpected product id still
// shows up there even if it lands in neither split.
export const premiumBreakdown = (entitlements: Entitlement[], now: Date): PremiumBreakdown => {
  const active = entitlements.filter((entitlement) => isActive(entitlement, now))
  const of = (suffix: string) =>
    Count(active.filter(({ productId }) => (productId as string).endsWith(suffix)).length)
  return { total: Count(active.length), monthly: of('.monthly'), yearly: of('.yearly') }
}
