import { describe, expect, test } from 'bun:test'
import { BookId } from '~/domain/book/primitives'
import type { Book } from '~/domain/book/types'
import {
  authorsOf,
  csvRowsOf,
  delimiterOf,
  importablesFrom,
  shelfKeyOf,
} from '~/domain/kindle/business-rules'
import { AuthorName, BookTitle, UserId } from '~/domain/shared/primitives'

const owned = (title: string, author: string): Book => ({
  id: BookId(title),
  userId: UserId('reader'),
  title: BookTitle(title),
  authors: [AuthorName(author)],
  format: 'ebook',
  subgenres: [],
  narrators: [],
  status: 'to-read',
  hidden: false,
  addedAt: new Date('2026-01-01'),
})

const titles = (found: ReturnType<typeof importablesFrom>) =>
  Array.isArray(found) ? found.map((book) => String(book.title)) : found

describe('delimiterOf', () => {
  test('reads a comma, a semicolon or a tab off the header line', () => {
    expect(delimiterOf('Title,Author\nDune,Herbert')).toBe(',')
    expect(delimiterOf('Title;Author;ASIN\nDune;Herbert;B01')).toBe(';')
    expect(delimiterOf('Title\tAuthor\nDune\tHerbert')).toBe('\t')
  })
})

describe('csvRowsOf', () => {
  // Everything a spreadsheet does to a file, in one row.
  test('reads a quoted field holding the separator, a line break and a quote', () => {
    const rows = csvRowsOf('A,B\n"Dune, tome 1","Il a dit ""non""\nà tous"\n', ',')
    expect(rows).toEqual([
      ['A', 'B'],
      ['Dune, tome 1', 'Il a dit "non"\nà tous'],
    ])
  })

  test('drops the byte order mark, the carriage returns and the blank last row', () => {
    expect(csvRowsOf('﻿Title,Author\r\nDune,Herbert\r\n\r\n', ',')).toEqual([
      ['Title', 'Author'],
      ['Dune', 'Herbert'],
    ])
  })
})

describe('authorsOf', () => {
  test('turns a catalogue name back around', () => {
    expect(authorsOf('Rothfuss, Patrick')).toEqual(['Patrick Rothfuss'])
  })

  // A guess that reorders a name is worse than a name read oddly.
  test('leaves a suffix and anything with two commas alone', () => {
    expect(authorsOf('Smith, Jr.')).toEqual(['Smith, Jr.'])
    expect(authorsOf('Dupont, Jean, Marie')).toEqual(['Dupont, Jean, Marie'])
  })

  test('splits several people on a semicolon or a pipe', () => {
    expect(authorsOf('Herbert, Frank; Anderson, Kevin')).toEqual([
      'Frank Herbert',
      'Kevin Anderson',
    ])
    expect(authorsOf('Frank Herbert|Kevin Anderson')).toEqual(['Frank Herbert', 'Kevin Anderson'])
  })
})

describe('importablesFrom', () => {
  test('reads the titles and their authors, whatever the columns are called', () => {
    const csv = ['Product Name;Author Name;ASIN', 'Dune;Herbert, Frank;B01'].join('\n')

    expect(importablesFrom(csv, [])).toEqual([
      {
        key: shelfKeyOf('Dune', 'Frank Herbert'),
        title: BookTitle('Dune'),
        authors: [AuthorName('Frank Herbert')],
        alreadyInLibrary: false,
      },
    ])
  })

  // The export is a purchase history: a book bought twice is one book.
  test('keeps one row per title and author however often it was bought', () => {
    const csv = ['Title,Author', 'Dune,Frank Herbert', 'Dune,Frank Herbert'].join('\n')

    expect(titles(importablesFrom(csv, []))).toEqual(['Dune'])
  })

  test('ticks off a title already on the shelf, whatever edition it came from', () => {
    const csv = ['Title,Author', 'Dune,"Herbert, Frank"'].join('\n')

    const found = importablesFrom(csv, [owned('Dune', 'Frank Herbert')])

    expect(Array.isArray(found) && found[0].alreadyInLibrary).toBe(true)
  })

  test('skips a row with no title rather than cataloguing a blank', () => {
    const csv = ['Title,Author', ',Frank Herbert', 'Dune,Frank Herbert'].join('\n')

    expect(titles(importablesFrom(csv, []))).toEqual(['Dune'])
  })

  test('reads a file that names no author at all', () => {
    const found = importablesFrom(['Title', 'Dune'].join('\n'), [])

    expect(Array.isArray(found) && found[0].authors).toEqual([])
  })

  // The wrong CSV out of the archive must be said so: an empty list would read
  // as "nothing to import", which is a different thing.
  test('refuses a file with no column that could hold a title', () => {
    const csv = ['Order Date,Total', '2026-01-01,12.99'].join('\n')

    expect(importablesFrom(csv, [])).toBe('no-title-column')
  })

  test('refuses an empty file', () => {
    expect(importablesFrom('', [])).toBe('no-title-column')
  })
})
