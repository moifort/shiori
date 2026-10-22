import { describe, expect, test } from 'bun:test'
import {
  boxOf,
  freeSearchesSpent,
  heldFormatOf,
  inReadingOrder,
  typedQueryOf,
} from '~/domain/scan/business-rules'

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

describe('heldFormatOf', () => {
  test('reads a cover shown on an e-reader as a book held on a screen', () => {
    expect(heldFormatOf('ebook')).toEqual({ format: 'book', media: ['digital'] })
  })

  test('says nothing of the medium for anything else', () => {
    expect(heldFormatOf('manga')).toEqual({ format: 'manga' })
    expect(heldFormatOf(null)).toEqual({})
    expect(heldFormatOf('scroll')).toEqual({})
  })
})

describe("when Gemini's free searches are spent", () => {
  // 6.3 searches a call: 714 calls is 4,498 searches, 715 is 4,504.
  test('not before the margin under the 5,000 free', () => {
    expect(freeSearchesSpent(0)).toBe(false)
    expect(freeSearchesSpent(714)).toBe(false)
  })

  test('from the margin on, and for the rest of the month', () => {
    expect(freeSearchesSpent(715)).toBe(true)
    expect(freeSearchesSpent(2000)).toBe(true)
  })
})

describe('typedQueryOf', () => {
  test('splits the author the app names beside a picked title', () => {
    expect(typedQueryOf('La Horde du Contrevent — Alain Damasio')).toEqual({
      title: 'La Horde du Contrevent',
      author: 'Alain Damasio',
    })
  })

  test('cuts at the last dash, so a title holding one keeps it', () => {
    expect(typedQueryOf('Dune — Le Messie — Frank Herbert')).toEqual({
      title: 'Dune — Le Messie',
      author: 'Frank Herbert',
    })
  })

  test('leaves a title typed alone, or a dash with nothing on one side, whole', () => {
    expect(typedQueryOf('Projet dernière chance')).toEqual({ title: 'Projet dernière chance' })
    expect(typedQueryOf('— Andy Weir')).toEqual({ title: '— Andy Weir' })
    expect(typedQueryOf('Projet dernière chance — ')).toEqual({
      title: 'Projet dernière chance — ',
    })
  })
})
