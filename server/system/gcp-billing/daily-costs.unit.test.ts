import { describe, expect, test } from 'bun:test'
import { parseDailyCosts } from '~/system/gcp-billing/daily-costs'

const row = (...values: (string | null)[]) => ({ f: values.map((v) => ({ v })) })

describe('reading the billing export s answer', () => {
  test('one entry per day, Gemini and infrastructure apart', () => {
    const days = parseDailyCosts({
      jobComplete: true,
      rows: [row('2026-10-03', '0.825', '0.31'), row('2026-10-04', '0.1', null)],
    })

    expect(days).toEqual([
      { day: '2026-10-03', geminiEur: 0.825, infraEur: 0.31 },
      { day: '2026-10-04', geminiEur: 0.1, infraEur: 0 },
    ])
  })

  test('a day the free tier more than covered reads zero, never a negative amount', () => {
    const days = parseDailyCosts({ jobComplete: true, rows: [row('2026-10-03', '0', '-0.01')] })

    expect(days[0]?.infraEur).toBe(0)
  })

  test('a month with no billed day yet is an empty list', () => {
    expect(parseDailyCosts({ jobComplete: true })).toEqual([])
  })

  test('a query that did not finish in time is an error, not an empty month', () => {
    expect(() => parseDailyCosts({ jobComplete: false })).toThrow()
  })
})
