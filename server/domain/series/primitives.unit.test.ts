import { describe, expect, test } from 'bun:test'
import {
  isAudioSeries,
  SeriesId,
  seriesIdFor,
  seriesKeyOf,
  VolumeNumber,
} from '~/domain/series/primitives'

describe('seriesKeyOf', () => {
  // The catalogue is global and paid for once. Two readers scanning volumes of
  // the same saga must reach the same document, or the AI call is paid twice and
  // the two copies drift apart.
  test('converges on one key despite accents, case, and punctuation', () => {
    const canonical = String(seriesKeyOf("L'Assassin royal", 'Robin Hobb', 'book'))
    expect(String(seriesKeyOf('assassin royal', 'robin hobb', 'book'))).toBe(canonical)
    expect(String(seriesKeyOf('L’Assassin Royal', 'Robin HOBB', 'book'))).toBe(canonical)
  })

  test('drops a leading article so "The Wheel of Time" and "Wheel of Time" agree', () => {
    expect(String(seriesKeyOf('The Wheel of Time', 'Robert Jordan', 'book'))).toBe(
      String(seriesKeyOf('Wheel of Time', 'Robert Jordan', 'book')),
    )
  })

  // Series names collide across authors far more often than titles do, which is
  // why the author is part of the key rather than a field beside it.
  test('keeps two same-named sagas by different authors apart', () => {
    expect(String(seriesKeyOf('Chronicles', 'Alice Ward', 'book'))).not.toBe(
      String(seriesKeyOf('Chronicles', 'Bob Stone', 'book')),
    )
  })
})

describe('the format in the key', () => {
  // A recording trails its printed book, sometimes by years, and some are never
  // made: a saga heard on Audible has a spine of its own.
  test('parts a saga heard from the same saga read', () => {
    const heard = seriesKeyOf('Bobiverse', 'Dennis E. Taylor', 'audiobook')
    expect(String(heard)).toBe('bobiverse--dennis-e-taylor--audio')
    expect(isAudioSeries(heard)).toBe(true)
  })

  test('keeps every other format on the printed saga', () => {
    const read = String(seriesKeyOf('Bobiverse', 'Dennis E. Taylor', 'book'))
    expect(read).toBe('bobiverse--dennis-e-taylor')
    for (const format of ['ebook', 'bande-dessinee', 'comic', 'manga'] as const)
      expect(String(seriesKeyOf('Bobiverse', 'Dennis E. Taylor', format))).toBe(read)
    expect(isAudioSeries(SeriesId(read))).toBe(false)
  })

  test('moves an id to the saga of a format, and back', () => {
    const read = SeriesId('bobiverse--dennis-e-taylor')
    const heard = SeriesId('bobiverse--dennis-e-taylor--audio')
    expect(seriesIdFor(read, 'audiobook')).toBe(heard)
    expect(seriesIdFor(heard, 'audiobook')).toBe(heard)
    expect(seriesIdFor(heard, 'book')).toBe(read)
    expect(seriesIdFor(read, 'manga')).toBe(read)
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
