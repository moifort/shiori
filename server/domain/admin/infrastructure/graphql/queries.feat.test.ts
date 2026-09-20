import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { graphql } from 'graphql'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { schema } = await import('~/domain/shared/graphql/schema')

const userId = 'reader-1' as UserId

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const execute = (source: string) => graphql({ schema, source, contextValue: { event: {}, userId } })

const seedProfile = (admin: boolean) => {
  fake.seed('users', userId, {
    userId,
    firstName: 'Thibaut',
    onboardingCompletedAt: new Date('2026-09-01T00:00:00.000Z'),
    ...(admin ? { admin: true } : {}),
  })
}

const metricsQuery = `query {
  adminMetrics {
    aiCostEur
    infraEur
    totalCostEur
    totalUsers
    premiumTotal
    premiumMonthly
    premiumYearly
    revenueProceedsEur
    revenueGrossEur
    scans
    cacheHits
    vision { promptTokens outputTokens thinkingTokens }
    enrichment { promptTokens }
    catalogue { promptTokens }
    refreshedAt
  }
}`

describe('who may read the admin metrics', () => {
  test('an ordinary account is refused with FORBIDDEN', async () => {
    seedProfile(false)

    const result = await execute(metricsQuery)

    expect(result.errors?.[0]?.extensions?.code).toBe('FORBIDDEN')
    expect(result.data).toBeNull()
  })

  test('an account without any profile is refused too', async () => {
    const result = await execute(metricsQuery)

    expect(result.errors?.[0]?.extensions?.code).toBe('FORBIDDEN')
  })

  test('an admin account gets the payload before the first refresh has ever run', async () => {
    seedProfile(true)

    const result = await execute(metricsQuery)

    expect(result.errors).toBeUndefined()
    expect(result.data?.adminMetrics).toMatchObject({
      aiCostEur: 0,
      infraEur: null,
      totalCostEur: 0,
      totalUsers: 0,
      premiumTotal: 0,
      revenueProceedsEur: null,
      scans: 0,
      cacheHits: 0,
      catalogue: { promptTokens: 0 },
      refreshedAt: null,
    })
  })

  test('serves what the projection and the month s counters hold', async () => {
    seedProfile(true)
    fake.seed('admin-metrics', 'current', {
      totalUsers: 42,
      premium: { total: 5, monthly: 2, yearly: 3 },
      revenue: { month: '2026-09', proceedsEur: 12.4, grossEur: 17.9 },
      infra: { month: '2026-09', gcpCostEur: 0.19 },
      refreshedAt: new Date('2026-09-20T04:00:00.000Z'),
    })

    const result = await execute(metricsQuery)

    expect(result.errors).toBeUndefined()
    expect(result.data?.adminMetrics).toMatchObject({
      totalUsers: 42,
      premiumTotal: 5,
      premiumMonthly: 2,
      premiumYearly: 3,
      revenueProceedsEur: 12.4,
      revenueGrossEur: 17.9,
      infraEur: 0.19,
      refreshedAt: '2026-09-20T04:00:00.000Z',
    })
  })
})
