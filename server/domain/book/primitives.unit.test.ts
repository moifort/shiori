import { describe, expect, test } from 'bun:test'
import {
  BookFormatValue,
  CoverUrl,
  GenreValue,
  Isbn13,
  PageCount,
  StarRating,
  Subgenre,
} from '~/domain/book/primitives'

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

describe('CoverUrl', () => {
  test('accepts an HTTPS image URL', () => {
    const url = 'https://covers.openlibrary.org/b/isbn/9780756404741-M.jpg?default=false'
    expect(String(CoverUrl(url))).toBe(url)
  })

  // App Transport Security blocks plain HTTP: stored, such a cover would never draw.
  test('refuses a plain HTTP URL and anything that is not a URL', () => {
    expect(() => CoverUrl('http://covers.openlibrary.org/b/isbn/9780756404741-M.jpg')).toThrow()
    expect(() => CoverUrl('not a url')).toThrow()
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

describe('BookFormatValue', () => {
  test('accepts every known format', () => {
    expect(BookFormatValue('manga')).toBe('manga')
    expect(BookFormatValue('bande-dessinee')).toBe('bande-dessinee')
  })

  // The model is handed the enum, but a format outside it must never be stored:
  // the app has no label to draw for it.
  test('refuses a format it does not know', () => {
    expect(() => BookFormatValue('novel')).toThrow()
  })
})

describe('GenreValue', () => {
  test('accepts a genre of the closed list', () => {
    expect(GenreValue('science-fiction')).toBe('science-fiction')
  })

  test('refuses a free label, even a plausible one', () => {
    expect(() => GenreValue('Fantasy')).toThrow()
    expect(() => GenreValue('epic-fantasy')).toThrow()
  })
})

describe('Subgenre', () => {
  test('trims a free label', () => {
    expect(String(Subgenre('  Dark fantasy '))).toBe('Dark Fantasy')
  })

  test('raises the first letter of every word and keeps the capitals already there', () => {
    expect(String(Subgenre('space opera'))).toBe('Space Opera')
    expect(String(Subgenre('LitRPG'))).toBe('LitRPG')
    expect(String(Subgenre('litRPG progression'))).toBe('LitRPG Progression')
  })

  test('keeps the minor words lowered, except at the start', () => {
    expect(String(Subgenre('roman De gare'))).toBe('Roman de Gare')
    expect(String(Subgenre('science et magie'))).toBe('Science et Magie')
    expect(String(Subgenre('le cycle'))).toBe('Le Cycle')
    expect(String(Subgenre('roman d’aventure'))).toBe('Roman d’Aventure')
    expect(String(Subgenre("l'épée et la magie"))).toBe("L'Épée et la Magie")
  })

  test('refuses an empty label and one past 100 characters', () => {
    expect(() => Subgenre('   ')).toThrow()
    expect(() => Subgenre('x'.repeat(101))).toThrow()
  })
})
