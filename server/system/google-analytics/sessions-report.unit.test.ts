import { describe, expect, test } from 'bun:test'
import { parseSessionsReport } from '~/system/google-analytics/sessions-report'

const row = (date: string, sessions: string) => ({
  dimensionValues: [{ value: date }],
  metricValues: [{ value: sessions }],
})

describe('reading GA4 s sessions report', () => {
  test('one entry per day, dated as a calendar day and in day order', () => {
    const days = parseSessionsReport({ rows: [row('20261004', '12'), row('20261002', '7')] })

    expect(days).toEqual([
      { day: '2026-10-02', sessions: 7 },
      { day: '2026-10-04', sessions: 12 },
    ])
  })

  test('a report with no row is a month without sessions', () => {
    expect(parseSessionsReport({})).toEqual([])
  })

  test('a row GA4 dated in another shape is left out rather than misdated', () => {
    expect(parseSessionsReport({ rows: [row('(other)', '3')] })).toEqual([])
  })
})
