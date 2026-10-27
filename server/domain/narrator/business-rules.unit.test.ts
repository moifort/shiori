import { describe, expect, test } from 'bun:test'
import type { NarratorName } from '~/domain/book/types'
import { isWorthDescribing } from '~/domain/narrator/business-rules'
import type { Narrator, NarratorKey } from '~/domain/narrator/types'

const now = new Date('2026-10-27T12:00:00Z')
const daysAgo = (days: number) => new Date(now.getTime() - days * 86_400_000)
const entry = (fields: Partial<Narrator>): Narrator => ({
  key: 'bernard-gabay' as NarratorKey,
  name: 'Bernard Gabay' as NarratorName,
  ...fields,
})

describe('isWorthDescribing', () => {
  test('asks about a narrator nobody described', () => {
    expect(isWorthDescribing(null, now)).toBe(true)
    // A face stored before narrators were described.
    expect(isWorthDescribing(entry({ portraitSoughtAt: daysAgo(2) }), now)).toBe(true)
  })

  test('never asks again about one described', () => {
    expect(isWorthDescribing(entry({ cataloguedAt: daysAgo(400) }), now)).toBe(false)
  })

  test('asks again about a miss a month on, not before', () => {
    expect(isWorthDescribing(entry({ missedAt: daysAgo(29) }), now)).toBe(false)
    expect(isWorthDescribing(entry({ missedAt: daysAgo(30) }), now)).toBe(true)
  })
})
