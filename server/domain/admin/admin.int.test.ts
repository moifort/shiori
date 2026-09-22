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

let gcpCost: number | undefined
let gcpFails = false
mock.module('~/system/gcp-billing', () => ({
  GcpBilling: {
    monthCost: async () => {
      if (gcpFails) throw new Error('BigQuery is down')
      return gcpCost
    },
  },
}))

const { AdminCommand } = await import('~/domain/admin/command')
const { AdminQuery } = await import('~/domain/admin/query')
const { AdminUseCase } = await import('~/domain/admin/use-case')
const { monthOf } = await import('~/domain/admin/business-rules')

const month = monthOf(new Date()) as string

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

const seedProfile = (id: string) => {
  fake.seed('users', id, {
    userId: id,
    firstName: 'Someone',
    onboardingCompletedAt: new Date('2026-09-01T00:00:00.000Z'),
  })
}

const seedEntitlement = (id: string, productId: string, expiresAt: Date) => {
  fake.seed('entitlements', id, {
    userId: id as UserId,
    productId,
    originalTransactionId: '2000000900000001',
    appAccountToken: `token-${id}`,
    expiresAt,
    updatedAt: new Date('2026-09-01T00:00:00.000Z'),
  })
}

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
  ascSales = undefined
  ascFails = false
  gcpCost = undefined
  gcpFails = false
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

  test('stores the revenue and the GCP bill when their sources answer', async () => {
    ascSales = { proceedsEur: 12.4, grossEur: 17.9 }
    gcpCost = 0.42

    const projection = await AdminUseCase.refreshMetrics()

    expect(projection.revenue).toMatchObject({ month, proceedsEur: 12.4, grossEur: 17.9 })
    expect(projection.infra).toMatchObject({ month, gcpCostEur: 0.42 })
  })

  test('leaves revenue and infra absent while their sources are unconfigured', async () => {
    const projection = await AdminUseCase.refreshMetrics()

    expect(projection.revenue).toBeUndefined()
    expect(projection.infra).toBeUndefined()
    expect(fake.snapshot('admin-metrics').get('current')).not.toContainKeys(['revenue', 'infra'])
  })

  test('a failing source keeps the last stored figure rather than erasing it', async () => {
    fake.seed('admin-metrics', 'current', {
      totalUsers: 1,
      premium: { total: 0, monthly: 0, yearly: 0 },
      revenue: { month: '2026-08', proceedsEur: 9.9, grossEur: 14 },
      infra: { month: '2026-08', gcpCostEur: 0.3 },
      refreshedAt: new Date('2026-08-31T04:00:00.000Z'),
    })
    ascFails = true
    gcpFails = true

    const projection = await AdminUseCase.refreshMetrics()

    expect(projection.revenue).toMatchObject({ proceedsEur: 9.9 })
    expect(projection.infra).toMatchObject({ gcpCostEur: 0.3 })
  })

  test('reads one document and two collection-wide queries, however many readers exist', async () => {
    seedProfile('u1')
    seedProfile('u2')

    await AdminUseCase.refreshMetrics()

    // The previous projection (keyed read), plus the profiles count() aggregate
    // and the entitlements stream — never a per-reader read.
    expect(fake.docReads).toBe(1)
    expect(fake.queryReads).toBe(2)
  })
})

describe('reading the metrics view', () => {
  test('joins the live month usage with the projection and prices it', async () => {
    await scanned({ vision: step(1_000_000, 0, 0) })
    gcpCost = 0.5
    await AdminUseCase.refreshMetrics()

    const view = await AdminQuery.metrics()

    expect(view.scans as number).toBe(1)
    expect(view.searches as number).toBe(0)
    // What a token costs is the unit test's business, and it changes with the
    // calendar — asserting a figure here would turn this into a test that fails
    // on a date. What matters is that the live month reached the view at all.
    expect(view.aiCostEur as number).toBeGreaterThan(0)
    // Infra is the measured GCP bill alone, no fixed Apple line added.
    expect(view.infraEur as number).toBeCloseTo(0.5, 10)
    expect(view.totalCostEur as number).toBeCloseTo((view.aiCostEur as number) + 0.5, 10)
    expect(view.refreshedAt).toBeInstanceOf(Date)
  })

  test('works before the first refresh: zeros and nulls, never a crash', async () => {
    const view = await AdminQuery.metrics()

    expect(view.totalUsers as number).toBe(0)
    expect(view.premium).toMatchObject({ total: 0, monthly: 0, yearly: 0 })
    expect(view.revenue).toBeUndefined()
    expect(view.refreshedAt).toBeUndefined()
    expect(view.searches as number).toBe(0)
    expect(view.searchCostEur as number).toBe(0)
    expect(view.tokenCostEur as number).toBe(0)
    // No billing export yet: infra is unavailable and the total is AI only.
    expect(view.infraEur).toBeUndefined()
    expect(view.totalCostEur as number).toBe(0)
  })
})
