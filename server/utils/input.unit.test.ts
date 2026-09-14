import { describe, expect, it } from 'bun:test'
import { stripNulls } from './input'

// Mirrors how Pothos types optional input fields: `T | null | undefined`.
type FakeInput = {
  name: string
  vintage?: number | null
  notes?: string | null
  price?: number | null
  favorite?: boolean | null
}

describe('stripNulls', () => {
  it('drops null keys entirely instead of keeping them', () => {
    const input: FakeInput = { name: 'Margaux', vintage: null }
    const out = stripNulls(input)
    expect(out).toEqual({ name: 'Margaux' })
    expect('vintage' in out).toBe(false)
  })

  it('keeps falsy but present values (0, empty string, false)', () => {
    const input: FakeInput = { name: 'Chinon', price: 0, notes: '', favorite: false }
    expect(stripNulls(input)).toEqual({ name: 'Chinon', price: 0, notes: '', favorite: false })
  })

  it('never introduces a null value: every remaining key holds a real value', () => {
    const input: FakeInput = { name: 'Cornas', vintage: 2019, notes: null, price: null }
    const out = stripNulls(input)
    expect(Object.values(out).every((value) => value !== null)).toBe(true)
    expect(out).toEqual({ name: 'Cornas', vintage: 2019 })
  })

  it('leaves objects without nulls untouched', () => {
    const input: FakeInput = { name: 'Chinon', vintage: 2020 }
    expect(stripNulls(input)).toEqual({ name: 'Chinon', vintage: 2020 })
  })

  it('is not recursive: nested values pass through as-is', () => {
    // Every mutation input in the schema is flat; nested objects pass through.
    const nested = { meta: { inner: null } as { inner: string | null } }
    expect(stripNulls(nested)).toEqual({ meta: { inner: null } })
  })
})
