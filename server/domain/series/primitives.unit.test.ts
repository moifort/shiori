import { describe, expect, test } from 'bun:test'
import { seriesKeyOf, VolumeNumber } from '~/domain/series/primitives'

describe('seriesKeyOf', () => {
  // The catalogue is global and paid for once. Two readers scanning volumes of
  // the same saga must reach the same document, or the AI call is paid twice and
  // the two copies drift apart.
  test('converges on one key despite accents, case, and punctuation', () => {
    const canonical = String(seriesKeyOf("L'Assassin royal", 'Robin Hobb'))
    expect(String(seriesKeyOf('assassin royal', 'robin hobb'))).toBe(canonical)
    expect(String(seriesKeyOf('L’Assassin Royal', 'Robin HOBB'))).toBe(canonical)
  })

  test('drops a leading article so "The Wheel of Time" and "Wheel of Time" agree', () => {
    expect(String(seriesKeyOf('The Wheel of Time', 'Robert Jordan'))).toBe(
      String(seriesKeyOf('Wheel of Time', 'Robert Jordan')),
    )
  })

  // Series names collide across authors far more often than titles do, which is
  // why the author is part of the key rather than a field beside it.
  test('keeps two same-named sagas by different authors apart', () => {
    expect(String(seriesKeyOf('Chronicles', 'Alice Ward'))).not.toBe(
      String(seriesKeyOf('Chronicles', 'Bob Stone')),
    )
  })
})

describe('VolumeNumber', () => {
  test('accepts a real position along the spine', () => {
    expect(Number(VolumeNumber(3))).toBe(3)
  })

  // "Book 0" prequel notation belongs in kind: 'prequel', not in the numbering.
  test('refuses zero and negative positions', () => {
    expect(() => VolumeNumber(0)).toThrow()
    expect(() => VolumeNumber(-1)).toThrow()
  })
})
