import type { AdminMetricsView, AiStepUsage } from '~/domain/admin/types'
import { builder } from '~/domain/shared/graphql/builder'

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

export const AdminMetricsType = builder.objectRef<AdminMetricsView>('AdminMetrics').implement({
  description:
    "The app's monthly economics, for the admin screen: what the month costs (measured AI " +
    'tokens, measured GCP billing) against what it brings in (App Store sales) and who is here ' +
    '(accounts, subscribers).\n\n' +
    'AI figures are live, incremented at each scan, and split into what the tokens cost and ' +
    'what the grounded searches cost — two different levers, and past a few thousand searches ' +
    'a month the second is the larger. Users, subscribers, revenue and the GCP bill come from ' +
    'a projection a scheduler refreshes daily — `refreshedAt` says when, and is null until it ' +
    'has run once.',
  fields: (t) => ({
    tokenCostEur: t.expose('tokenCostEur', {
      type: 'Eur',
      description: "This month's Gemini tokens, priced from what the API reported, e.g. `0.30`",
    }),
    searchCostEur: t.expose('searchCostEur', {
      type: 'Eur',
      description:
        "This month's grounded searches, e.g. `0.12`. Reads `0` until the 5,000 free searches " +
        'of the month are spent, which is a real zero and not a missing figure — past that, ' +
        'one search costs more than all the tokens of the scan that ran it.',
    }),
    aiCostEur: t.expose('aiCostEur', {
      type: 'Eur',
      description: "This month's whole Gemini bill: tokens and searches together, e.g. `0.42`",
    }),
    infraEur: t.expose('infraEur', {
      type: 'Eur',
      nullable: true,
      description:
        "This month's measured GCP bill for the project, from the billing export, e.g. `0.19`; " +
        'null while the export is not configured or has never answered. Carries no fixed line: ' +
        'the Apple Developer fee is shared across projects and deliberately left out.',
    }),
    totalCostEur: t.expose('totalCostEur', {
      type: 'Eur',
      description: 'AI plus the measured infrastructure bill, e.g. `0.61`',
    }),
    totalUsers: t.int({
      description: 'How many accounts completed onboarding, e.g. `42`',
      resolve: (metrics) => metrics.totalUsers,
    }),
    premiumTotal: t.int({
      description: 'Active Premium subscribers right now, e.g. `5`',
      resolve: (metrics) => metrics.premium.total,
    }),
    premiumMonthly: t.int({
      description: 'Of them, on the monthly plan, e.g. `2`',
      resolve: (metrics) => metrics.premium.monthly,
    }),
    premiumYearly: t.int({
      description: 'Of them, on the yearly plan, e.g. `3`',
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
        'Google searches run this month, free allowance included, e.g. `812`. Watch it against ' +
        'the 5,000 free ones: the cost stays at zero right up to the last of them.\n\n' +
        'An estimate rather than the invoice — Gemini does not always report the searches it ' +
        'ran while thinking, and a grounded call that reports none is counted as one.',
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
        "The series-catalogue step's token consumption this month. Runs only for a saga no " +
        'reader has catalogued yet, so it is the line that spikes on a new author.',
      resolve: (metrics) => metrics.catalogue,
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
