import { describe, expect, test } from 'bun:test'
import { Isbn13, PageCount, StarRating } from '~/domain/book/primitives'

describe('Isbn13', () => {
  test('accepts a valid ISBN-13 and strips its separators', () => {
    expect(String(Isbn13('978-0-7564-0474-1'))).toBe('9780756404741')
    expect(String(Isbn13('978 0 7564 0474 1'))).toBe('9780756404741')
  })

  // The whole reason the check digit is verified: a model asked for an ISBN
  // returns something ISBN-shaped whether or not it knows one, and a wrong ISBN
  // poisons every later lookup silently.
  test('refuses a 13-digit number whose check digit does not match', () => {
    expect(() => Isbn13('9780756404742')).toThrow()
  })

  test('refuses anything that is not thirteen digits', () => {
    expect(() => Isbn13('0756404746')).toThrow()
    expect(() => Isbn13('not-an-isbn')).toThrow()
  })
})

describe('StarRating', () => {
  test('accepts one to five whole stars', () => {
    expect(Number(StarRating(1))).toBe(1)
    expect(Number(StarRating(5))).toBe(5)
  })

  test('refuses half stars, zero, and anything past five', () => {
    expect(() => StarRating(3.5)).toThrow()
    expect(() => StarRating(0)).toThrow()
    expect(() => StarRating(6)).toThrow()
  })
})

describe('PageCount', () => {
  // An unknown page count is an absent field. Storing zero would render as a real
  // count of nothing, and the AI returns zero when it has no idea.
  test('refuses zero rather than storing an unknown count', () => {
    expect(() => PageCount(0)).toThrow()
  })

  test('accepts a real page count', () => {
    expect(Number(PageCount(662))).toBe(662)
  })
})
