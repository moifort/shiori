import type { AiStepUsage, AiUsage, PremiumBreakdown } from '~/domain/admin/types'
import { isActive } from '~/domain/entitlement/business-rules'
import type { Entitlement } from '~/domain/entitlement/types'
import { Count, Eur, Month } from '~/domain/shared/primitives'
import type { Eur as EurType, Month as MonthType } from '~/domain/shared/types'

// The Gemini Flash list prices the scan is costed against: $0.30 per million
// input tokens, $2.50 per million output tokens — and thinking tokens bill at
// the output rate, which is why they are tracked apart. Carried over from the
// tier's published rates rather than measured here: confirm them against the
// current price list for the model `server/domain/scan/gemini.ts` calls, and
// revise here, which is the only place they are written down.
const INPUT_USD_PER_TOKEN = 0.3 / 1_000_000
const OUTPUT_USD_PER_TOKEN = 2.5 / 1_000_000

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

// What the month's measured tokens cost in euros, every Gemini call combined.
export const aiCostEur = (usage: AiUsage): EurType => {
  const steps = [usage.vision, usage.enrichment, usage.catalogue]
  const promptTokens = steps.reduce((sum, step) => sum + step.promptTokens, 0)
  const billedAsOutput = steps.reduce(
    (sum, step) => sum + step.outputTokens + step.thinkingTokens,
    0,
  )
  const usd = promptTokens * INPUT_USD_PER_TOKEN + billedAsOutput * OUTPUT_USD_PER_TOKEN
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
