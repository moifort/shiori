import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { ScanUsage } from '~/domain/scan/types'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

// The two external sources are stubbed: what is asserted is how the refresh
// composes them into the projection, not Apple's or BigQuery's answers.
let ascSales: { proceedsEur: number; grossEur: number } | undefined
let ascFails = false
mock.module('~/system/appstore-connect', () => ({
  AppStoreConnect: {
    monthSales: async () => {
      if (ascFails) throw new Error('Apple is down')
      return ascSales
    },
  },
}))

type BilledDay = { day: string; geminiEur: number; infraEur: number }
let billedDays: Map<string, BilledDay[]> | undefined
let gcpFails = false
mock.module('~/system/gcp-billing', () => ({
  GcpBilling: {
    dailyCosts: async (month: string) => {
      if (gcpFails) throw new Error('BigQuery is down')
      return billedDays ? (billedDays.get(month) ?? []) : undefined
    },
  },
}))

let sessionDays: { day: string; sessions: number }[] | undefined
let gaFails = false
mock.module('~/system/google-analytics', () => ({
  GoogleAnalytics: {
    dailySessions: async () => {
      if (gaFails) throw new Error('GA4 is down')
      return sessionDays
    },
  },
}))

const { AdminCommand } = await import('~/domain/admin/command')
const { AdminQuery } = await import('~/domain/admin/query')
const { AdminUseCase } = await import('~/domain/admin/use-case')
const { isBilledMonth, monthOf, previousMonthOf } = await import('~/domain/admin/business-rules')

const month = monthOf(new Date()) as string
const previousMonth = previousMonthOf(monthOf(new Date())) as string
const lastYear = '2025-01'

const step = (
  promptTokens: number,
  outputTokens: number,
  thinkingTokens: number,
  searches = 0,
) => ({
  promptTokens,
  outputTokens,
  thinkingTokens,
  searches,
})

const scanned = (usage: ScanUsage) => AdminCommand.recordAiUsage({ cacheHit: false, usage })

const seedProfile = (id: string, onboardingCompletedAt = new Date('2025-01-15T00:00:00.000Z')) => {
  fake.seed('users', id, { userId: id, firstName: 'Someone', onboardingCompletedAt })
}

const seedEntitlement = (id: string, productId: string, expiresAt: Date, startedAt?: Date) => {
  fake.seed('entitlements', id, {
    userId: id as UserId,
    productId,
    originalTransactionId: '2000000900000001',
    appAccountToken: `token-${id}`,
    expiresAt,
    ...(startedAt ? { startedAt } : {}),
    updatedAt: new Date('2026-09-01T00:00:00.000Z'),
  })
}

// A moment inside the current month, whatever day the suite runs on.
const thisMonth = new Date(`${month}-01T12:00:00.000Z`)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
  ascSales = undefined
  ascFails = false
  billedDays = undefined
  gcpFails = false
  sessionDays = undefined
  gaFails = false
})

describe('recording a scan s AI usage', () => {
  test('two scans accumulate their tokens on the month s single document', async () => {
    await scanned({ vision: step(2600, 250, 1500), enrichment: step(5000, 200, 1400) })
    await scanned({ vision: step(400, 50, 100) })

    expect(fake.snapshot('ai-usage').get(month)).toMatchObject({
      month,
      scans: 2,
      cacheHits: 0,
      vision: { promptTokens: 3000, outputTokens: 300, thinkingTokens: 1600, searches: 0 },
      enrichment: { promptTokens: 5000, outputTokens: 200, thinkingTokens: 1400, searches: 0 },
    })
  })

  test('the saga catalogue is counted on its own, since it rarely runs', async () => {
    await scanned({ vision: step(2600, 250, 1500), enrichment: step(5000, 200, 1400) })
    await scanned({
      vision: step(2600, 250, 1500),
      enrichment: step(5000, 200, 1400),
      catalogue: step(3000, 400, 2000),
    })

    expect(fake.snapshot('ai-usage').get(month)).toMatchObject({
      scans: 2,
      catalogue: { promptTokens: 3000, outputTokens: 400, thinkingTokens: 2000 },
    })
  })

  test('a cache hit counts as a hit, never as a scan, and adds no tokens', async () => {
    await AdminCommand.recordAiUsage({ cacheHit: true, usage: {} })

    expect(fake.snapshot('ai-usage').get(month)).toMatchObject({
      scans: 0,
      cacheHits: 1,
      vision: { promptTokens: 0, outputTokens: 0, thinkingTokens: 0, searches: 0 },
      catalogue: { promptTokens: 0, outputTokens: 0, thinkingTokens: 0, searches: 0 },
    })
  })

  test('the searches of the grounded steps accumulate like the tokens do', async () => {
    await scanned({ vision: step(2600, 250, 1500), enrichment: step(5000, 200, 1400, 2) })
    await scanned({ enrichment: step(5000, 200, 1400, 1), catalogue: step(3000, 400, 2000, 3) })

    expect(fake.snapshot('ai-usage').get(month)).toMatchObject({
      vision: { searches: 0 },
      enrichment: { searches: 3 },
      catalogue: { searches: 3 },
    })
  })

  test('costs one write and zero reads: pure increments, no read-modify-write', async () => {
    await scanned({ vision: step(100, 10, 50) })

    expect(fake.docReads).toBe(0)
    expect(fake.queryReads).toBe(0)
    expect(fake.directWrites).toHaveLength(1)
    expect(fake.transactions).toHaveLength(0)
  })
})

describe('refreshing the metrics projection', () => {
  test('counts the accounts and splits the active subscribers', async () => {
    seedProfile('u1')
    seedProfile('u2')
    seedProfile('u3')
    const future = new Date('2099-01-01T00:00:00.000Z')
    seedEntitlement('u1', 'com.polyforms.shiori.app.premium.yearly', future)
    seedEntitlement('u2', 'com.polyforms.shiori.app.premium.monthly', future)
    seedEntitlement('u3', 'com.polyforms.shiori.app.premium.yearly', new Date('2026-01-01'))

    const projection = await AdminUseCase.refreshMetrics()

    expect(projection.totalUsers as number).toBe(3)
    expect(projection.premium).toMatchObject({ total: 2, monthly: 1, yearly: 1 })
    expect(fake.snapshot('admin-metrics').get('current')).toMatchObject({ totalUsers: 3 })
  })

  test('counts who joined and who subscribed this month, and no one before', async () => {
    seedProfile('old')
    seedProfile('new', thisMonth)
    const future = new Date('2099-01-01T00:00:00.000Z')
    seedEntitlement('old', 'com.polyforms.shiori.app.premium.yearly', future)
    seedEntitlement('new', 'com.polyforms.shiori.app.premium.monthly', future, thisMonth)

    const projection = await AdminUseCase.refreshMetrics()

    expect(projection.newUsers as number).toBe(1)
    expect(projection.newPremium as number).toBe(1)
  })

  test('stores the revenue, the bill day by day and the sessions when they answer', async () => {
    ascSales = { proceedsEur: 12.4, grossEur: 17.9 }
    billedDays = new Map([
      [month, [{ day: `${month}-01`, geminiEur: 0.4, infraEur: 0.2 }]],
      [previousMonth, [{ day: `${previousMonth}-12`, geminiEur: 5, infraEur: 1 }]],
    ])
    sessionDays = [{ day: `${month}-01`, sessions: 7 }]

    const projection = await AdminUseCase.refreshMetrics()

    expect(projection.revenue).toMatchObject({ month, proceedsEur: 12.4, grossEur: 17.9 })
    expect(projection.costs).toMatchObject({
      month,
      days: [{ day: `${month}-01`, geminiEur: 0.4, infraEur: 0.2 }],
    })
    expect(projection.sessions).toEqual({
      month,
      days: [{ day: `${month}-01`, sessions: 7 }],
    } as never)
  })

  test('compares with last month only when the export holds its whole bill', async () => {
    billedDays = new Map([
      [previousMonth, [{ day: `${previousMonth}-12`, geminiEur: 5, infraEur: 1 }]],
    ])

    const projection = await AdminUseCase.refreshMetrics()

    if (isBilledMonth(previousMonthOf(monthOf(new Date())))) {
      expect(projection.costs?.previousMonthEur as number).toBe(6)
    } else {
      expect(projection.costs?.previousMonthEur).toBeUndefined()
    }
  })

  test('leaves revenue, costs and sessions absent while their sources are unconfigured', async () => {
    const projection = await AdminUseCase.refreshMetrics()

    expect(projection.revenue).toBeUndefined()
    expect(projection.costs).toBeUndefined()
    expect(projection.sessions).toBeUndefined()
    expect(fake.snapshot('admin-metrics').get('current')).not.toContainKeys([
      'revenue',
      'costs',
      'sessions',
    ])
  })

  test('a failing source keeps the last figure of the same month rather than erasing it', async () => {
    fake.seed('admin-metrics', 'current', {
      totalUsers: 1,
      newUsers: 0,
      premium: { total: 0, monthly: 0, yearly: 0 },
      newPremium: 0,
      revenue: { month: '2026-08', proceedsEur: 9.9, grossEur: 14 },
      costs: { month, days: [{ day: `${month}-01`, geminiEur: 0.3, infraEur: 0.1 }] },
      sessions: { month, days: [{ day: `${month}-01`, sessions: 4 }] },
      refreshedAt: new Date(`${month}-02T04:00:00.000Z`),
    })
    ascFails = true
    gcpFails = true
    gaFails = true

    const projection = await AdminUseCase.refreshMetrics()

    expect(projection.revenue).toMatchObject({ proceedsEur: 9.9 })
    expect(projection.costs?.days).toHaveLength(1)
    expect(projection.sessions?.days).toHaveLength(1)
  })

  test('a failing source drops a figure measured in another month', async () => {
    fake.seed('admin-metrics', 'current', {
      totalUsers: 1,
      newUsers: 0,
      premium: { total: 0, monthly: 0, yearly: 0 },
      newPremium: 0,
      costs: { month: lastYear, days: [{ day: `${lastYear}-01`, geminiEur: 0.3, infraEur: 0.1 }] },
      sessions: { month: lastYear, days: [{ day: `${lastYear}-01`, sessions: 4 }] },
      refreshedAt: new Date(`${lastYear}-31T04:00:00.000Z`),
    })
    gcpFails = true
    gaFails = true

    const projection = await AdminUseCase.refreshMetrics()

    expect(projection.costs).toBeUndefined()
    expect(projection.sessions).toBeUndefined()
  })

  test('reads one document and three collection-wide queries, however many readers exist', async () => {
    seedProfile('u1')
    seedProfile('u2')

    await AdminUseCase.refreshMetrics()

    // The previous projection (keyed read), plus the two profile count()
    // aggregates and the entitlements stream — never a per-reader read.
    expect(fake.docReads).toBe(1)
    expect(fake.queryReads).toBe(3)
  })
})

describe('reading the metrics view', () => {
  test('joins the live month counters with the projection and reads the bill', async () => {
    await scanned({ vision: step(1000, 0, 0), enrichment: step(0, 0, 0, 2) })
    billedDays = new Map([[month, [{ day: `${month}-01`, geminiEur: 0.4, infraEur: 0.2 }]]])
    sessionDays = [{ day: `${month}-01`, sessions: 7 }]
    await AdminUseCase.refreshMetrics()

    const view = await AdminQuery.metrics()

    expect(view.scans as number).toBe(1)
    expect(view.searches as number).toBe(2)
    expect(view.costs?.geminiEur as number).toBeCloseTo(0.4, 10)
    expect(view.costs?.infraEur as number).toBeCloseTo(0.2, 10)
    expect(view.costs?.billedThrough as string).toBe(`${month}-01`)
    expect(view.sessions).toEqual([{ day: `${month}-01`, sessions: 7 }] as never)
    expect(view.refreshedAt).toBeInstanceOf(Date)
  })

  test('costs two document reads: the month counters and the projection', async () => {
    await AdminQuery.metrics()

    expect(fake.docReads).toBe(2)
    expect(fake.queryReads).toBe(0)
  })

  test('serves none of a projection s month figures once the month has turned', async () => {
    fake.seed('admin-metrics', 'current', {
      totalUsers: 3,
      newUsers: 2,
      premium: { total: 1, monthly: 0, yearly: 1 },
      newPremium: 1,
      costs: { month: lastYear, days: [{ day: `${lastYear}-01`, geminiEur: 0.3, infraEur: 0.1 }] },
      sessions: { month: lastYear, days: [{ day: `${lastYear}-01`, sessions: 4 }] },
      refreshedAt: new Date(`${lastYear}-31T04:00:00.000Z`),
    })

    const view = await AdminQuery.metrics()

    expect(view.totalUsers as number).toBe(3)
    expect(view.newUsers as number).toBe(0)
    expect(view.newPremium as number).toBe(0)
    expect(view.costs).toBeUndefined()
    expect(view.sessions).toBeUndefined()
  })

  test('works before the first refresh: zeros and nulls, never a crash', async () => {
    const view = await AdminQuery.metrics()

    expect(view.totalUsers as number).toBe(0)
    expect(view.newUsers as number).toBe(0)
    expect(view.premium).toMatchObject({ total: 0, monthly: 0, yearly: 0 })
    expect(view.revenue).toBeUndefined()
    expect(view.costs).toBeUndefined()
    expect(view.sessions).toBeUndefined()
    expect(view.refreshedAt).toBeUndefined()
    expect(view.searches as number).toBe(0)
  })
})
