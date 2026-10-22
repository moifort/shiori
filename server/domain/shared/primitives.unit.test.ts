import { describe, expect, test } from 'bun:test'
import { AuthorName, BookTitle, Day } from '~/domain/shared/primitives'

describe('a calendar day', () => {
  test('is a dashed year, month and day', () => {
    expect(Day('2026-10-04') as string).toBe('2026-10-04')
  })

  test('refuses a month or a day written another way', () => {
    expect(() => Day('2026-10')).toThrow()
    expect(() => Day('04/10/2026')).toThrow()
  })
})

describe('a title or an author', () => {
  test('is written with single spaces', () => {
    expect(BookTitle('  La Horde  du\tContrevent\n') as string).toBe('La Horde du Contrevent')
    expect(AuthorName('Alain   Damasio') as string).toBe('Alain Damasio')
  })

  test('refuses nothing but spaces', () => {
    expect(() => BookTitle(' \n\t ')).toThrow()
  })
})
