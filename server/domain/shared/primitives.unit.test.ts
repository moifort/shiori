import { describe, expect, test } from 'bun:test'
import { Day } from '~/domain/shared/primitives'

describe('a calendar day', () => {
  test('is a dashed year, month and day', () => {
    expect(Day('2026-10-04') as string).toBe('2026-10-04')
  })

  test('refuses a month or a day written another way', () => {
    expect(() => Day('2026-10')).toThrow()
    expect(() => Day('04/10/2026')).toThrow()
  })
})
