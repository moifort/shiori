import type {
  AiStepUsage,
  AiUsage,
  DailyCost,
  MonthCosts,
  MonthCostsView,
  PremiumBreakdown,
} from '~/domain/admin/types'
import { isActive } from '~/domain/entitlement/business-rules'
import type { Entitlement } from '~/domain/entitlement/types'
import { Count, Eur, Month } from '~/domain/shared/primitives'
import type { Count as CountType, Day, Month as MonthType } from '~/domain/shared/types'

// The first month the billing export holds the whole of Shiori's bill. Until
// October 3rd 2026 Gemini was billed to the shared "Perso" project, which is
// not on this billing account: September holds Shiori's infrastructure but none
// of its Gemini. A month before this one counts as absent, so the screen shows
// no comparison rather than one against half a bill.
export const FIRST_BILLED_MONTH = Month('2026-10')

// The month a moment belongs to, `"2026-09"`, also the ai-usage document id.
// UTC on purpose, mirroring the quota month: the window must not move with
// anyone's timezone. The billing export dates its usage in UTC as well.
export const monthOf = (moment: Date): MonthType =>
  Month(`${moment.getUTCFullYear()}-${String(moment.getUTCMonth() + 1).padStart(2, '0')}`)

const yearAndMonth = (month: MonthType) =>
  (month as string).split('-').map(Number) as [number, number]

export const isBilledMonth = (month: MonthType): boolean =>
  (month as string) >= (FIRST_BILLED_MONTH as string)

export const previousMonthOf = (month: MonthType): MonthType => {
  const [year, index] = yearAndMonth(month)
  return monthOf(new Date(Date.UTC(year, index - 2, 1)))
}

export const daysInMonth = (month: MonthType): number => {
  const [year, index] = yearAndMonth(month)
  return new Date(Date.UTC(year, index, 0)).getUTCDate()
}

// Midnight UTC on the month's first day: where "joined this month" starts.
export const monthStart = (month: MonthType): Date => {
  const [year, index] = yearAndMonth(month)
  return new Date(Date.UTC(year, index - 1, 1))
}

const dayOfMonth = (day: Day): number => Number((day as string).slice(8, 10))

const sum = (days: DailyCost[], line: (day: DailyCost) => number) =>
  days.reduce((total, day) => total + line(day), 0)

// The month's bill as the screen reads it. The projection extends the daily
// average over the days the export has reached — about a day behind, so up to
// yesterday — to the whole month. It counts the calendar days elapsed, not the
// rows: a day nothing was billed on still spent its share of the month.
export const monthCostsView = (costs: MonthCosts): MonthCostsView => {
  const days = [...costs.days].sort((a, b) => ((a.day as string) < (b.day as string) ? -1 : 1))
  const geminiEur = sum(days, (day) => day.geminiEur)
  const infraEur = sum(days, (day) => day.infraEur)
  const totalEur = geminiEur + infraEur
  const billedThrough = days.at(-1)?.day
  const projectedEur = billedThrough
    ? (totalEur / dayOfMonth(billedThrough)) * daysInMonth(costs.month)
    : undefined
  const previous = costs.previousMonthEur
  const change = projectedEur !== undefined && previous ? projectedEur / previous - 1 : undefined
  return {
    geminiEur: Eur(geminiEur),
    infraEur: Eur(infraEur),
    totalEur: Eur(totalEur),
    ...(projectedEur !== undefined ? { projectedEur: Eur(projectedEur) } : {}),
    ...(previous !== undefined ? { previousMonthEur: previous } : {}),
    ...(change !== undefined ? { changeVsPreviousMonth: change } : {}),
    ...(billedThrough ? { billedThrough } : {}),
    days,
  }
}

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

// How many searches the month ran, every step combined.
export const searchesOf = (usage: AiUsage): CountType =>
  Count(stepsOf(usage).reduce((total, step) => total + step.searches, 0))

// Who is Premium right now, split by the billing period the product id names.
// `total` counts every active entitlement, so an unexpected product id still
// shows up there even if it lands in neither split.
export const premiumBreakdown = (entitlements: Entitlement[], now: Date): PremiumBreakdown => {
  const active = entitlements.filter((entitlement) => isActive(entitlement, now))
  const of = (suffix: string) =>
    Count(active.filter(({ productId }) => (productId as string).endsWith(suffix)).length)
  return { total: Count(active.length), monthly: of('.monthly'), yearly: of('.yearly') }
}

// Who subscribed during the month, a free trial included — whether or not they
// still are. An entitlement recorded before `startedAt` existed has none and is
// not counted: it predates the month anyway, and its next renewal fills it in.
export const newPremiumIn = (entitlements: Entitlement[], month: MonthType): CountType =>
  Count(
    entitlements.filter(({ startedAt }) => startedAt !== undefined && monthOf(startedAt) === month)
      .length,
  )
