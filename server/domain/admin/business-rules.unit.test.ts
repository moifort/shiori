import { describe, expect, test } from 'bun:test'
import {
  aiCostEur,
  freshUsage,
  monthOf,
  premiumBreakdown,
  searchCostEur,
  searchesOf,
  tokenCostEur,
} from '~/domain/admin/business-rules'
import type { AiStepUsage, AiUsage } from '~/domain/admin/types'
import type { Entitlement, ProductId } from '~/domain/entitlement/types'
import type { Count, Month, UserId } from '~/domain/shared/types'

const month = '2026-09' as Month

const step = (
  promptTokens: number,
  outputTokens: number,
  thinkingTokens: number,
  searches = 0,
): AiStepUsage => ({
  promptTokens: promptTokens as Count,
  outputTokens: outputTokens as Count,
  thinkingTokens: thinkingTokens as Count,
  searches: searches as Count,
})

const none = step(0, 0, 0)

const usage = (
  vision: AiStepUsage,
  enrichment: AiStepUsage = none,
  catalogue: AiStepUsage = none,
): AiUsage => ({
  month,
  scans: 1 as Count,
  cacheHits: 0 as Count,
  vision,
  enrichment,
  catalogue,
})

describe('pricing the month s AI consumption', () => {
  test('a month without a single scan costs nothing', () => {
    expect(aiCostEur(freshUsage(month)) as number).toBe(0)
    expect(tokenCostEur(freshUsage(month)) as number).toBe(0)
    expect(searchCostEur(freshUsage(month)) as number).toBe(0)
  })

  test('input tokens bill at the input rate', () => {
    // 1M input tokens at $0.30/M and a 0.91 USD→EUR conversion.
    expect(tokenCostEur(usage(step(1_000_000, 0, 0))) as number).toBeCloseTo(0.3 * 0.91, 10)
  })

  test('thinking tokens bill at the output rate, the point of tracking them apart', () => {
    const thinking = tokenCostEur(usage(step(0, 0, 1_000_000)))
    const output = tokenCostEur(usage(step(0, 1_000_000, 0)))
    expect(thinking as number).toBe(output as number)
    expect(thinking as number).toBeCloseTo(2.5 * 0.91, 10)
  })

  test('the three steps add up', () => {
    const visionOnly = tokenCostEur(usage(step(2600, 250, 1500)))
    const enrichmentOnly = tokenCostEur(usage(none, step(5000, 200, 1500)))
    const catalogueOnly = tokenCostEur(usage(none, none, step(3000, 400, 2000)))
    const all = tokenCostEur(
      usage(step(2600, 250, 1500), step(5000, 200, 1500), step(3000, 400, 2000)),
    )
    expect(all as number).toBeCloseTo(
      (visionOnly as number) + (enrichmentOnly as number) + (catalogueOnly as number),
      10,
    )
  })

  test('a scan of an already-catalogued saga costs about a cent in tokens', () => {
    // The two steps a routine scan runs: ~2.6K in, ~250 out, ~1.5K thinking for
    // the cover; ~5K in, ~200 out, ~1.5K thinking for the enrichment. The saga
    // catalogue does not run, which is what makes the routine scan the cheap one.
    // This is the number the scan allowances in the quota domain are sized on.
    const cost = tokenCostEur(usage(step(2600, 250, 1500), step(5000, 200, 1500)))
    expect(cost as number).toBeGreaterThan(0.005)
    expect(cost as number).toBeLessThan(0.015)
  })
})

describe('pricing the month s grounded searches', () => {
  const withSearches = (count: number) => ({
    ...usage(none, step(0, 0, 0, count)),
  })

  test('the free allowance of the month costs nothing, right up to the last one', () => {
    expect(searchCostEur(withSearches(1)) as number).toBe(0)
    expect(searchCostEur(withSearches(4999)) as number).toBe(0)
    expect(searchCostEur(withSearches(5000)) as number).toBe(0)
  })

  test('past the allowance only the searches beyond it are billed', () => {
    // 1000 billable searches at $14 per thousand, converted at 0.91.
    expect(searchCostEur(withSearches(6000)) as number).toBeCloseTo(14 * 0.91, 10)
  })

  test('one billed search costs more than the tokens of the scan that ran it', () => {
    const scan = tokenCostEur(usage(step(2600, 250, 1500), step(5000, 200, 1500)))
    const oneSearch = (searchCostEur(withSearches(5001)) as number) - 0

    expect(oneSearch).toBeGreaterThan(scan as number)
  })

  test('the searches of every step add up, wherever they were run', () => {
    const spread = {
      ...usage(step(0, 0, 0, 1), step(0, 0, 0, 2), step(0, 0, 0, 3)),
    }
    // Six searches, all inside the allowance, so what is asserted is the sum
    // reaching the pricing at all rather than a figure.
    expect(searchCostEur(spread) as number).toBe(0)
    expect(searchesOf(spread) as number).toBe(6)
  })
})

describe('what the whole Gemini bill adds up to', () => {
  test('is the tokens plus the searches', () => {
    const month = {
      ...usage(step(2600, 250, 1500), step(5000, 200, 1500, 6000)),
    }

    expect(aiCostEur(month) as number).toBeCloseTo(
      (tokenCostEur(month) as number) + (searchCostEur(month) as number),
      10,
    )
    expect(searchCostEur(month) as number).toBeGreaterThan(0)
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
