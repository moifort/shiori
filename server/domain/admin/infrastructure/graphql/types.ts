import type {
  AdminMetricsView,
  AiStepUsage,
  DailyCost,
  DailySessions,
  MonthCostsView,
} from '~/domain/admin/types'
import { builder } from '~/domain/shared/graphql/builder'
import { Eur } from '~/domain/shared/primitives'

const AiTokenUsageType = builder.objectRef<AiStepUsage>('AiTokenUsage').implement({
  description:
    'What one Gemini step consumed this month, in tokens as the API reported them.\n\n' +
    'Thinking tokens are listed apart from plain output because they bill at the output rate ' +
    'and are the largest line on a scan.',
  fields: (t) => ({
    promptTokens: t.int({
      description: 'Input tokens (the cover photo, the prompt), e.g. `2600`',
      resolve: (usage) => usage.promptTokens,
    }),
    outputTokens: t.int({
      description: 'Visible output tokens (the structured answer), e.g. `250`',
      resolve: (usage) => usage.outputTokens,
    }),
    thinkingTokens: t.int({
      description: 'Reasoning tokens, billed at the output rate, e.g. `1500`',
      resolve: (usage) => usage.thinkingTokens,
    }),
    searches: t.int({
      description:
        'Google searches this step ran, billed one by one on top of the tokens, e.g. `2`. ' +
        'Always `0` for the cover step, which is deliberately not grounded.',
      resolve: (usage) => usage.searches,
    }),
  }),
})

const AdminDailyCostType = builder.objectRef<DailyCost>('AdminDailyCost').implement({
  description: 'What the bill says one day cost the project, credits (the free tier) included.',
  fields: (t) => ({
    day: t.expose('day', { type: 'Day', description: 'The usage day, UTC, e.g. `"2026-10-03"`' }),
    geminiEur: t.expose('geminiEur', {
      type: 'Eur',
      description: 'The Gemini API that day, tokens and grounded searches, e.g. `0.83`',
    }),
    infraEur: t.expose('infraEur', {
      type: 'Eur',
      description: 'Every other service of the project that day, e.g. `0.04`',
    }),
  }),
})

const AdminDailySessionsType = builder.objectRef<DailySessions>('AdminDailySessions').implement({
  description: 'How many sessions GA4 counted on one day.',
  fields: (t) => ({
    day: t.expose('day', { type: 'Day', description: 'The day, e.g. `"2026-10-03"`' }),
    sessions: t.int({
      description: 'Sessions that day, e.g. `14`',
      resolve: (entry) => entry.sessions,
    }),
  }),
})

const AdminMonthCostsType = builder.objectRef<MonthCostsView>('AdminMonthCosts').implement({
  description:
    "The month's bill so far, read from the billing export: what AI Studio's Spend page " +
    'shows for Gemini, and the rest of the project as infrastructure.\n\n' +
    'The export runs about a day behind, so `billedThrough` is usually yesterday or the day ' +
    'before, and today is never in it.',
  fields: (t) => ({
    geminiEur: t.expose('geminiEur', {
      type: 'Eur',
      description: "The month's Gemini API bill so far, e.g. `4.12`",
    }),
    infraEur: t.expose('infraEur', {
      type: 'Eur',
      description: "The month's infrastructure bill so far, e.g. `0.95`",
    }),
    totalEur: t.expose('totalEur', {
      type: 'Eur',
      description: 'Both together, e.g. `5.07`',
    }),
    projectedEur: t.expose('projectedEur', {
      type: 'Eur',
      nullable: true,
      description:
        'The whole month at the daily average of the days billed so far, e.g. `52.4`; null ' +
        'until a first day is billed.',
    }),
    previousMonthEur: t.expose('previousMonthEur', {
      type: 'Eur',
      nullable: true,
      description:
        "Last month's whole bill, e.g. `46.8`; null when the export does not hold all of it.",
    }),
    changeVsPreviousMonth: t.float({
      nullable: true,
      description:
        'The projection against last month, as a ratio: `0.12` is 12 % more, `-0.3` 30 % less. ' +
        'Null without a projection or a previous month.',
      resolve: (costs) => costs.changeVsPreviousMonth,
    }),
    billedThrough: t.expose('billedThrough', {
      type: 'Day',
      nullable: true,
      description: 'The last day the export has reached, e.g. `"2026-10-03"`; null before any.',
    }),
    days: t.field({
      type: [AdminDailyCostType],
      description: 'One entry per billed day, in day order. A day with no line is absent.',
      resolve: (costs) => costs.days,
    }),
  }),
})

const replacedByCosts = 'Use `costs`, read from the bill rather than priced from the tokens.'

export const AdminMetricsType = builder.objectRef<AdminMetricsView>('AdminMetrics').implement({
  description:
    "The app's month, for the admin screen: what it costs (the bill, day by day), what it " +
    'brings in (App Store sales), who is here and who came (accounts, subscribers), and how ' +
    'much the app is used (GA4 sessions).\n\n' +
    'The bill, the sessions, the accounts, the subscribers and the revenue come from a ' +
    'projection a scheduler refreshes daily — `refreshedAt` says when, and is null until it ' +
    'has run once. The Gemini call counters (scans, cache hits, searches) are live.',
  fields: (t) => ({
    costs: t.field({
      type: AdminMonthCostsType,
      nullable: true,
      description:
        "This month's bill; null while the billing export is not configured or has not " +
        'answered this month.',
      resolve: (metrics) => metrics.costs,
    }),
    sessions: t.field({
      type: [AdminDailySessionsType],
      nullable: true,
      description:
        "This month's sessions per day, in day order; null while GA4 is not configured or has " +
        'not answered this month.',
      resolve: (metrics) => metrics.sessions,
    }),
    tokenCostEur: t.field({
      type: 'Eur',
      deprecationReason: replacedByCosts,
      description: 'No longer measured: always `0`.',
      resolve: () => Eur(0),
    }),
    searchCostEur: t.field({
      type: 'Eur',
      deprecationReason: replacedByCosts,
      description: 'No longer measured: always `0`.',
      resolve: () => Eur(0),
    }),
    aiCostEur: t.field({
      type: 'Eur',
      deprecationReason: replacedByCosts,
      description: "This month's Gemini bill so far, `0` while it is unknown.",
      resolve: (metrics) => metrics.costs?.geminiEur ?? Eur(0),
    }),
    infraEur: t.field({
      type: 'Eur',
      nullable: true,
      deprecationReason: replacedByCosts,
      description: "This month's infrastructure bill so far; null while it is unknown.",
      resolve: (metrics) => metrics.costs?.infraEur,
    }),
    totalCostEur: t.field({
      type: 'Eur',
      deprecationReason: replacedByCosts,
      description: "This month's whole bill so far, `0` while it is unknown.",
      resolve: (metrics) => metrics.costs?.totalEur ?? Eur(0),
    }),
    totalUsers: t.int({
      description: 'How many accounts completed onboarding, e.g. `42`',
      resolve: (metrics) => metrics.totalUsers,
    }),
    newUsers: t.int({
      description: 'Of them, how many completed it this month, e.g. `6`',
      resolve: (metrics) => metrics.newUsers,
    }),
    premiumTotal: t.int({
      description: 'Active Premium subscribers right now, e.g. `5`',
      resolve: (metrics) => metrics.premium.total,
    }),
    newPremium: t.int({
      description:
        'Subscriptions that began this month, a free trial included, whether or not they are ' +
        'still active, e.g. `2`',
      resolve: (metrics) => metrics.newPremium,
    }),
    premiumMonthly: t.int({
      deprecationReason: 'The admin screen no longer splits subscribers by plan.',
      description: 'Active subscribers on the monthly plan, e.g. `2`',
      resolve: (metrics) => metrics.premium.monthly,
    }),
    premiumYearly: t.int({
      deprecationReason: 'The admin screen no longer splits subscribers by plan.',
      description: 'Active subscribers on the yearly plan, e.g. `3`',
      resolve: (metrics) => metrics.premium.yearly,
    }),
    revenueProceedsEur: t.field({
      type: 'Eur',
      nullable: true,
      description:
        "This month's App Store net proceeds (what Apple pays out), e.g. `12.4`; null while " +
        'the App Store Connect key is not configured or has never answered.',
      resolve: (metrics) => metrics.revenue?.proceedsEur,
    }),
    revenueGrossEur: t.field({
      type: 'Eur',
      nullable: true,
      description: "This month's App Store gross (what customers paid), e.g. `17.9`",
      resolve: (metrics) => metrics.revenue?.grossEur,
    }),
    scans: t.int({
      description: 'Scans that really reached Gemini this month, e.g. `37`',
      resolve: (metrics) => metrics.scans,
    }),
    cacheHits: t.int({
      description: 'Scan requests served from the cover cache this month, at no cost, e.g. `4`',
      resolve: (metrics) => metrics.cacheHits,
    }),
    searches: t.int({
      description:
        'Google searches run this month, e.g. `812` — the line the Gemini bill turns on once ' +
        'the free monthly allowance is spent.\n\n' +
        'Counted by the app, not billed: Gemini does not always report the searches it ran ' +
        'while thinking, and a grounded call that reports none is counted as one.',
      resolve: (metrics) => metrics.searches,
    }),
    vision: t.field({
      type: AiTokenUsageType,
      description: "The cover-reading step's token consumption this month. Runs on every scan.",
      resolve: (metrics) => metrics.vision,
    }),
    enrichment: t.field({
      type: AiTokenUsageType,
      description:
        "The web-grounded enrichment step's token consumption this month. Skipped when the " +
        'cover was not recognized.',
      resolve: (metrics) => metrics.enrichment,
    }),
    catalogue: t.field({
      type: AiTokenUsageType,
      description:
        "The catalogue steps' token consumption this month, sagas and authors alike. Runs " +
        'only for a saga or an author nobody has catalogued yet, so it is the line that ' +
        'spikes on a new author.',
      resolve: (metrics) => metrics.catalogue,
    }),
    discovery: t.field({
      type: AiTokenUsageType,
      description:
        "The Découvrir tab's token consumption this month: each reader's weekly suggestions, " +
        'the award lists shared per genre, and the release dates of followed sagas and authors.',
      resolve: (metrics) => metrics.discovery,
    }),
    refreshedAt: t.expose('refreshedAt', {
      type: 'DateTime',
      nullable: true,
      description:
        'When the daily projection last ran, e.g. `"2026-09-20T04:00:00.000Z"`; null before ' +
        'its first run.',
    }),
  }),
})
