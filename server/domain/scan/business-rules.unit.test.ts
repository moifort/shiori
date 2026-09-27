import { describe, expect, test } from 'bun:test'
import { boxOf, inReadingOrder } from '~/domain/scan/business-rules'

describe('boxOf', () => {
  test('turns Gemini’s [ymin, xmin, ymax, xmax] on 0–1000 into fractions of the photo', () => {
    expect(boxOf([100, 200, 900, 250])).toEqual({ x: 0.2, y: 0.1, width: 0.05, height: 0.8 })
  })

  test('clamps a corner the model drew outside the photo', () => {
    expect(boxOf([-20, 950, 500, 1040])).toEqual({ x: 0.95, y: 0, width: 0.05, height: 0.5 })
  })

  test('refuses a box that is not four numbers, or has no area', () => {
    expect(boxOf([1, 2, 3])).toBeUndefined()
    expect(boxOf([100, 200, 100, 300])).toBeUndefined()
    expect(boxOf([100, 300, 200, 300])).toBeUndefined()
    expect(boxOf([100, Number.NaN, 200, 300])).toBeUndefined()
  })
})

describe('inReadingOrder', () => {
  const at = (id: string, x: number, y: number, width = 0.1, height = 0.3) => ({
    id,
    box: { x, y, width, height },
  })

  test('reads a shelf of spines left to right, whatever their heights', () => {
    const books = [
      at('c', 0.5, 0.12, 0.05, 0.7),
      at('a', 0.1, 0.1, 0.05, 0.8),
      at('b', 0.3, 0.2, 0.05, 0.6),
    ]
    expect(inReadingOrder(books).map(({ id }) => id)).toEqual(['a', 'b', 'c'])
  })

  test('reads two shelves top to bottom, each left to right', () => {
    const books = [at('d', 0.6, 0.55), at('b', 0.6, 0.05), at('c', 0.1, 0.6), at('a', 0.1, 0.1)]
    expect(inReadingOrder(books).map(({ id }) => id)).toEqual(['a', 'b', 'c', 'd'])
  })
})
