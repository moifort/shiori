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

const month = new Date().toISOString().slice(0, 7)
const [year, monthIndex] = month.split('-').map(Number) as [number, number]
const daysInMonth = new Date(Date.UTC(year, monthIndex, 0)).getUTCDate()

const metricsQuery = `query {
  adminMetrics {
    costs {
      geminiEur
      infraEur
      totalEur
      projectedEur
      previousMonthEur
      changeVsPreviousMonth
      billedThrough
      days { day geminiEur infraEur }
    }
    sessions { day sessions }
    totalUsers
    newUsers
    premiumTotal
    newPremium
    revenueProceedsEur
    revenueGrossEur
    scans
    cacheHits
    searches
    vision { promptTokens outputTokens thinkingTokens searches }
    enrichment { promptTokens searches }
    catalogue { promptTokens searches }
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
      costs: null,
      sessions: null,
      totalUsers: 0,
      newUsers: 0,
      premiumTotal: 0,
      newPremium: 0,
      revenueProceedsEur: null,
      scans: 0,
      cacheHits: 0,
      searches: 0,
      vision: { promptTokens: 0, searches: 0 },
      catalogue: { promptTokens: 0, searches: 0 },
      refreshedAt: null,
    })
  })

  test('serves the month s bill, its projection and the sessions the projection holds', async () => {
    seedProfile(true)
    fake.seed('admin-metrics', 'current', {
      totalUsers: 42,
      newUsers: 6,
      premium: { total: 5, monthly: 2, yearly: 3 },
      newPremium: 2,
      revenue: { month, proceedsEur: 12.4, grossEur: 17.9 },
      costs: {
        month,
        days: [
          { day: `${month}-02`, geminiEur: 0.5, infraEur: 0.25 },
          { day: `${month}-01`, geminiEur: 1, infraEur: 0.25 },
        ],
      },
      sessions: { month, days: [{ day: `${month}-01`, sessions: 14 }] },
      refreshedAt: new Date(`${month}-03T04:00:00.000Z`),
    })

    const result = await execute(metricsQuery)

    expect(result.errors).toBeUndefined()
    expect(result.data?.adminMetrics).toMatchObject({
      costs: {
        geminiEur: 1.5,
        infraEur: 0.5,
        totalEur: 2,
        // 2 € over the first two days, extended to every day of the month.
        projectedEur: daysInMonth,
        previousMonthEur: null,
        changeVsPreviousMonth: null,
        billedThrough: `${month}-02`,
        days: [
          { day: `${month}-01`, geminiEur: 1, infraEur: 0.25 },
          { day: `${month}-02`, geminiEur: 0.5, infraEur: 0.25 },
        ],
      },
      sessions: [{ day: `${month}-01`, sessions: 14 }],
      totalUsers: 42,
      newUsers: 6,
      premiumTotal: 5,
      newPremium: 2,
      revenueProceedsEur: 12.4,
      revenueGrossEur: 17.9,
      refreshedAt: `${month}-03T04:00:00.000Z`,
    })
  })

  test('still answers the fields the earlier builds ask for, from the bill', async () => {
    seedProfile(true)
    fake.seed('admin-metrics', 'current', {
      totalUsers: 1,
      newUsers: 0,
      premium: { total: 1, monthly: 0, yearly: 1 },
      newPremium: 0,
      costs: { month, days: [{ day: `${month}-01`, geminiEur: 1, infraEur: 0.5 }] },
      refreshedAt: new Date(`${month}-02T04:00:00.000Z`),
    })

    const result = await execute(`query {
      adminMetrics {
        tokenCostEur searchCostEur aiCostEur infraEur totalCostEur premiumMonthly premiumYearly
      }
    }`)

    expect(result.errors).toBeUndefined()
    expect(result.data?.adminMetrics).toEqual({
      tokenCostEur: 0,
      searchCostEur: 0,
      aiCostEur: 1,
      infraEur: 0.5,
      totalCostEur: 1.5,
      premiumMonthly: 0,
      premiumYearly: 1,
    })
  })
})
