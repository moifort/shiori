import { describe, expect, test } from 'bun:test'
import { winnersOfAnswer } from './wikidata'

const binding = (title: string, year: string, authors: string) => ({
  title: { value: title },
  year: { value: year },
  authors: { value: authors },
})

describe('winnersOfAnswer', () => {
  test('reads each work, its year and its authors in order', () => {
    expect(
      winnersOfAnswer([
        binding('The Everlasting', '2026', 'Alix E. Harrow'),
        binding('Good Omens', '1991', 'Terry Pratchett|Neil Gaiman'),
      ]),
    ).toEqual([
      { year: 2026, title: 'The Everlasting', authors: ['Alix E. Harrow'] },
      { year: 1991, title: 'Good Omens', authors: ['Terry Pratchett', 'Neil Gaiman'] },
    ])
  })

  test('drops a work with no author or no year', () => {
    expect(
      winnersOfAnswer([binding('Untitled', '2026', ''), binding('Undated', 'soon', 'Somebody')]),
    ).toEqual([])
  })
})
