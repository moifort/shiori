import { describe, expect, test } from 'bun:test'
import {
  daysInMonth,
  isBilledMonth,
  monthCostsView,
  monthOf,
  monthStart,
  newPremiumIn,
  premiumBreakdown,
  previousMonthOf,
} from '~/domain/admin/business-rules'
import type { DailyCost, MonthCosts } from '~/domain/admin/types'
import type { Entitlement, ProductId } from '~/domain/entitlement/types'
import type { Count, Day, Eur, Month, UserId } from '~/domain/shared/types'

const october = '2026-10' as Month

const day = (date: string, geminiEur: number, infraEur: number): DailyCost => ({
  day: date as Day,
  geminiEur: geminiEur as Eur,
  infraEur: infraEur as Eur,
})

const costs = (days: DailyCost[], previousMonthEur?: number): MonthCosts => ({
  month: october,
  days,
  ...(previousMonthEur !== undefined ? { previousMonthEur: previousMonthEur as Eur } : {}),
})

describe('the month arithmetic', () => {
  test('the month before January is December of the year before', () => {
    expect(previousMonthOf('2026-01' as Month) as string).toBe('2025-12')
    expect(previousMonthOf(october) as string).toBe('2026-09')
  })

  test('a month knows how many days it has, February included', () => {
    expect(daysInMonth('2026-02' as Month)).toBe(28)
    expect(daysInMonth('2028-02' as Month)).toBe(29)
    expect(daysInMonth(october)).toBe(31)
  })

  test('a month starts at midnight UTC on its first day', () => {
    expect(monthStart(october).toISOString()).toBe('2026-10-01T00:00:00.000Z')
  })

  test('September is not a billed month: its Gemini went to another project', () => {
    expect(isBilledMonth('2026-09' as Month)).toBe(false)
    expect(isBilledMonth(october)).toBe(true)
    expect(isBilledMonth('2027-01' as Month)).toBe(true)
  })
})

describe('reading the month s bill', () => {
  test('sums each line and extends the daily average to the whole month', () => {
    const view = monthCostsView(
      costs([
        day('2026-10-01', 0.5, 0.5),
        day('2026-10-02', 0.25, 0.25),
        day('2026-10-03', 1, 0.5),
      ]),
    )

    expect(view.geminiEur as number).toBeCloseTo(1.75, 10)
    expect(view.infraEur as number).toBeCloseTo(1.25, 10)
    expect(view.totalEur as number).toBeCloseTo(3, 10)
    expect(view.billedThrough as string).toBe('2026-10-03')
    // 3 € over three days, 31 days in October.
    expect(view.projectedEur as number).toBeCloseTo(31, 10)
  })

  test('counts the days elapsed, not the rows: a day with nothing billed still passed', () => {
    const view = monthCostsView(costs([day('2026-10-01', 1, 0), day('2026-10-04', 1, 0)]))

    expect(view.projectedEur as number).toBeCloseTo((2 / 4) * 31, 10)
  })

  test('sorts days the export returned out of order', () => {
    const view = monthCostsView(costs([day('2026-10-02', 1, 0), day('2026-10-01', 2, 0)]))

    expect(view.days.map((entry) => entry.day as string)).toEqual(['2026-10-01', '2026-10-02'])
    expect(view.billedThrough as string).toBe('2026-10-02')
  })

  test('compares the projection with last month s total', () => {
    const view = monthCostsView(costs([day('2026-10-01', 1, 0)], 15.5))

    expect(view.previousMonthEur as number).toBe(15.5)
    expect(view.changeVsPreviousMonth as number).toBeCloseTo(31 / 15.5 - 1, 10)
  })

  test('no comparison without a previous month, or against a month that cost nothing', () => {
    expect(monthCostsView(costs([day('2026-10-01', 1, 0)])).changeVsPreviousMonth).toBeUndefined()
    expect(
      monthCostsView(costs([day('2026-10-01', 1, 0)], 0)).changeVsPreviousMonth,
    ).toBeUndefined()
  })

  test('before the first billed day: zeros, and nothing to project', () => {
    const view = monthCostsView(costs([], 12))

    expect(view.totalEur as number).toBe(0)
    expect(view.projectedEur).toBeUndefined()
    expect(view.billedThrough).toBeUndefined()
    expect(view.changeVsPreviousMonth).toBeUndefined()
  })
})

describe('the month key', () => {
  test('is the UTC month, zero-padded', () => {
    expect(monthOf(new Date('2026-09-20T10:00:00.000Z')) as string).toBe('2026-09')
    expect(monthOf(new Date('2026-01-01T00:00:00.000Z')) as string).toBe('2026-01')
  })

  test('does not move with a timezone: the last hour of a UTC month still belongs to it', () => {
    expect(monthOf(new Date('2026-09-30T23:59:59.000Z')) as string).toBe('2026-09')
  })
})

describe('counting who is Premium', () => {
  const now = new Date('2026-09-20T00:00:00.000Z')

  const entitlement = (userId: string, productId: string, expiresAt: Date): Entitlement => ({
    userId: userId as UserId,
    productId: productId as ProductId,
    originalTransactionId: '2000000900000001' as Entitlement['originalTransactionId'],
    appAccountToken: 'bc4a0626-772c-4b01-a0ec-4d018ee55375' as Entitlement['appAccountToken'],
    expiresAt,
    updatedAt: now,
  })

  const future = new Date('2099-01-01T00:00:00.000Z')
  const past = new Date('2026-01-01T00:00:00.000Z')

  test('splits active subscribers by their billing period', () => {
    const breakdown = premiumBreakdown(
      [
        entitlement('u1', 'com.polyforms.shiori.app.premium.yearly', future),
        entitlement('u2', 'com.polyforms.shiori.app.premium.monthly', future),
        entitlement('u3', 'com.polyforms.shiori.app.premium.yearly', future),
      ],
      now,
    )
    expect(breakdown.total as number).toBe(3)
    expect(breakdown.monthly as number).toBe(1)
    expect(breakdown.yearly as number).toBe(2)
  })

  test('an expired or revoked entitlement counts for nothing', () => {
    const revoked = {
      ...entitlement('u2', 'com.polyforms.shiori.app.premium.monthly', future),
      revokedAt: past,
    }
    const breakdown = premiumBreakdown(
      [entitlement('u1', 'com.polyforms.shiori.app.premium.yearly', past), revoked],
      now,
    )
    expect(breakdown.total as number).toBe(0)
  })

  test('an unexpected product id still counts in the total', () => {
    const breakdown = premiumBreakdown(
      [entitlement('u1', 'com.polyforms.shiori.app.premium.lifetime', future)],
      now,
    )
    expect(breakdown.total as number).toBe(1)
    expect(breakdown.monthly as number).toBe(0)
    expect(breakdown.yearly as number).toBe(0)
  })

  test('nobody subscribed reads as zeros', () => {
    expect(premiumBreakdown([], now)).toEqual({
      total: 0 as Count,
      monthly: 0 as Count,
      yearly: 0 as Count,
    })
  })
})

describe('counting who subscribed this month', () => {
  const subscribed = (userId: string, startedAt?: Date): Entitlement => ({
    userId: userId as UserId,
    productId: 'com.polyforms.shiori.app.premium.yearly' as ProductId,
    originalTransactionId: '2000000900000001' as Entitlement['originalTransactionId'],
    appAccountToken: 'bc4a0626-772c-4b01-a0ec-4d018ee55375' as Entitlement['appAccountToken'],
    expiresAt: new Date('2099-01-01T00:00:00.000Z'),
    ...(startedAt ? { startedAt } : {}),
    updatedAt: new Date('2026-10-04T00:00:00.000Z'),
  })

  test('counts a chain that began in the month, and only those', () => {
    const count = newPremiumIn(
      [
        subscribed('u1', new Date('2026-10-02T09:00:00.000Z')),
        subscribed('u2', new Date('2026-09-30T23:59:59.000Z')),
        subscribed('u3'),
      ],
      october,
    )

    expect(count as number).toBe(1)
  })
})
