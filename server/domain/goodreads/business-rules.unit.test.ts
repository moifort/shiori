import { describe, expect, test } from 'bun:test'
import { BookId } from '~/domain/book/primitives'
import type { Book, BookLanguage } from '~/domain/book/types'
import {
  bookFrom,
  completionOf,
  dateIn,
  destinationOf,
  formatOf,
  isbnIn,
  noteFrom,
  previewOf,
  rowsOf,
  seriesIn,
  verdictsOf,
} from '~/domain/goodreads/business-rules'
import type { GoodreadsRow } from '~/domain/goodreads/types'
import { AuthorName, BookTitle, StarRating, UserId } from '~/domain/shared/primitives'
import { GOODREADS_EXPORT } from '~/test/goodreads-export'

const owned = (title: string, author: string, extra: Partial<Book> = {}): Book => ({
  id: BookId(title),
  userId: UserId('reader'),
  title: BookTitle(title),
  authors: [AuthorName(author)],
  format: 'book',
  media: ['print'],
  subgenres: [],
  narrators: [],
  status: 'to-read',
  hidden: false,
  addedAt: new Date('2026-01-01'),
  ...extra,
})

const languageOfIsbn = (isbn: string): BookLanguage | undefined =>
  isbn.startsWith('9782') ? 'fr' : isbn.startsWith('9780') ? 'en' : undefined

const rows = () => {
  const read = rowsOf(GOODREADS_EXPORT)
  if (typeof read === 'string') throw new Error(read)
  return read
}

const choices = {
  toRead: 'wishlist',
  keepRatings: true,
  keepDates: true,
  keepReviews: true,
} as const

describe('seriesIn', () => {
  test('reads the saga and its number off the end of the title', () => {
    expect(seriesIn('The Way of Kings (The Stormlight Archive, #1)')).toEqual({
      title: 'The Way of Kings',
      series: { name: 'The Stormlight Archive', volume: 1 },
    })
  })

  test('keeps the saga and drops a number that is not a whole one', () => {
    expect(seriesIn('Edgedancer (The Stormlight Archive, #2.5)')).toEqual({
      title: 'Edgedancer',
      series: { name: 'The Stormlight Archive', volume: undefined },
    })
  })

  test('leaves a title with no saga as it is', () => {
    expect(seriesIn('Le Nom du vent')).toEqual({ title: 'Le Nom du vent' })
  })
})

describe('the cells Goodreads writes', () => {
  test('reads an ISBN written as a spreadsheet formula, and an empty one as none', () => {
    expect(isbnIn('="9780765326355"')).toBe('9780765326355')
    expect(isbnIn('=""')).toBeUndefined()
  })

  test('reads a date with slashes at noon UTC, and refuses a day that does not exist', () => {
    expect(dateIn('2024/05/12')).toEqual(new Date(Date.UTC(2024, 4, 12, 12)))
    expect(dateIn('2024/02/30')).toBeUndefined()
    expect(dateIn('')).toBeUndefined()
  })

  test('tells a recording, an ebook and a paper book apart by the binding', () => {
    expect(formatOf('Audible Audio')).toEqual({ format: 'audiobook', media: [] })
    expect(formatOf('Kindle Edition')).toEqual({ format: 'book', media: ['digital'] })
    expect(formatOf('Mass Market Paperback')).toEqual({ format: 'book', media: ['print'] })
    expect(formatOf('Comics')).toEqual({ format: 'comic', media: ['print'] })
  })

  test('turns an HTML review into a note with its line breaks', () => {
    expect(String(noteFrom('Loved it.<br/><br/>Kaladin &amp; Syl!'))).toBe(
      'Loved it.\n\nKaladin & Syl!',
    )
    expect(noteFrom('')).toBeUndefined()
  })
})

describe('rowsOf', () => {
  test('reads every book of the export, once per title and author', () => {
    const titles = rows().map((row) => String(row.title))
    expect(titles).toEqual([
      'The Way of Kings',
      'Le Nom du vent',
      'Hypérion',
      'Fondation',
      'Le Problème à trois corps',
    ])
  })

  test('reads a rating of 0 as none, and a dnf shelf as given up', () => {
    const [kings, , hyperion, , problem] = rows()
    expect(kings.rating).toBe(StarRating(5))
    expect(hyperion.rating).toBeUndefined()
    expect(problem.dropped).toBe(true)
    expect(problem.shelf).toBe('read')
  })

  test('takes the ISBN-13, else turns the ISBN-10 into one', () => {
    const [kings] = rows()
    expect(String(kings.isbn13)).toBe('9780765326355')
    const tenOnly = rowsOf(GOODREADS_EXPORT.replace('"=""9780765326355"""', '"="""""'))
    if (typeof tenOnly === 'string') throw new Error(tenOnly)
    expect(String(tenOnly[0].isbn13)).toBe('9780765326355')
  })

  test('reads a real export end to end, every column as Goodreads writes it', () => {
    const [kings, wind, hyperion, foundation, problem] = rows()
    expect(kings).toMatchObject({
      title: BookTitle('The Way of Kings'),
      authors: [AuthorName('Brandon Sanderson')],
      series: { name: 'The Stormlight Archive', volume: 1 },
      shelf: 'read',
      dropped: false,
      format: 'book',
      media: ['print'],
      publisher: 'Tor Books',
      pageCount: 1007,
      firstPublishedIn: 2010,
    })
    expect(kings.readOn).toEqual(new Date('2024-05-12T12:00:00Z'))
    expect(kings.addedOn).toEqual(new Date('2024-04-01T12:00:00Z'))
    expect(String(kings.review)).toBe('Loved it.\n\nKaladin!')
    expect(String(wind.isbn13)).toBe('9782352942573')
    expect(Number(wind.firstPublishedIn)).toBe(2007)
    expect(hyperion.isbn13).toBeUndefined()
    expect(hyperion.shelf).toBe('currently-reading')
    expect(hyperion.media).toEqual(['digital'])
    expect(foundation.shelf).toBe('to-read')
    expect(foundation.dropped).toBe(false)
    expect(String(foundation.isbn13)).toBe('9782070360536')
    expect(problem.dropped).toBe(true)
    expect(problem.authors).toEqual([AuthorName('Liu Cixin')])
  })

  test('refuses a file without the Goodreads headings, and one with no book', () => {
    expect(rowsOf('Title,Author\nDune,Frank Herbert')).toBe('not-goodreads')
    expect(rowsOf(GOODREADS_EXPORT.split('\n')[0])).toBe('empty')
  })

  test('finds its columns by name, whatever their order', () => {
    const [header, first] = GOODREADS_EXPORT.split('\n')
    const swapped = `Exclusive Shelf,${header.replace(',Exclusive Shelf', '')}\nread,${first.replace(',read,', ',')}`
    const read = rowsOf(swapped)
    if (typeof read === 'string') throw new Error(read)
    expect(read[0].shelf).toBe('read')
  })
})

describe('verdictsOf', () => {
  test('holds a book the library keeps, by title and author or by ISBN', () => {
    const library = [owned('Le Nom du vent', 'Patrick Rothfuss', { language: 'fr' })]
    const verdicts = verdictsOf(rows(), library, languageOfIsbn)
    expect(verdicts.map((row) => row.verdict)).toEqual(['new', 'held', 'new', 'new', 'new'])
    expect(verdicts[1].heldBookId).toBe(BookId('Le Nom du vent'))
  })

  test('leaves a volume titled after its saga, by the same author, to the reader', () => {
    const library = [owned('Le Dernier Vœu', 'Andrzej Sapkowski')]
    const row = {
      ...rows()[1],
      title: BookTitle('Le Sorceleur, tome 1 : Le Dernier Vœu'),
      authors: [AuthorName('Andrzej Sapkowski')],
      isbn13: undefined,
    } satisfies GoodreadsRow
    const [verdict] = verdictsOf([row], library, languageOfIsbn)
    expect(verdict.verdict).toBe('uncertain')
  })

  test('does not hold an edition in another language', () => {
    const library = [owned('Le Nom du vent', 'Patrick Rothfuss', { language: 'en' })]
    const [, nameOfTheWind] = verdictsOf(rows(), library, languageOfIsbn)
    expect(nameOfTheWind.verdict).toBe('new')
  })

  test('counts each shelf, the given-up apart', () => {
    const preview = previewOf(verdictsOf(rows(), [], languageOfIsbn))
    expect(preview.shelves).toEqual({ read: 2, reading: 1, toRead: 1, dropped: 1 })
    expect(preview.rated).toBe(3)
    expect(preview.reviewed).toBe(1)
  })
})

describe('where a row lands', () => {
  test('sends to-read to the wishlist or the pile, as the reader chose', () => {
    const fondation = rows()[3]
    expect(destinationOf(fondation, { toRead: 'wishlist' })).toBe('wish')
    expect(destinationOf(fondation, { toRead: 'pile' })).toBe('to-read')
  })

  test('sends a given-up book to dropped whatever its shelf', () => {
    expect(destinationOf(rows()[4], { toRead: 'wishlist' })).toBe('dropped')
  })
})

describe('bookFrom', () => {
  const [kings] = verdictsOf(rows(), [], languageOfIsbn)

  test('carries the saga, the stars, the reading date and the review', () => {
    const book = bookFrom(kings, 'read', choices)
    expect(book.series?.name).toBe(kings.series?.name)
    expect(book.series?.volume).toBe(kings.series?.volume)
    expect(book.rating).toBe(StarRating(5))
    expect(book.finishedAt).toEqual(new Date(Date.UTC(2024, 4, 12, 12)))
    expect(String(book.note)).toBe('Loved it.\n\nKaladin!')
    expect(book.language).toBe('en')
    expect(book.origin).toEqual({ kind: 'goodreads' })
  })

  test('leaves out what the reader chose not to carry over, dating the reading from the shelf', () => {
    const book = bookFrom(kings, 'read', {
      ...choices,
      keepRatings: false,
      keepDates: false,
      keepReviews: false,
    })
    expect(book.rating).toBeUndefined()
    expect(book.note).toBeUndefined()
    expect(book.finishedAt).toEqual(new Date(Date.UTC(2024, 3, 1, 12)))
  })
})

describe('completionOf', () => {
  const [kings] = verdictsOf(rows(), [], languageOfIsbn)
  const input = bookFrom(kings, 'read', choices)

  test('brings what the held book lacks', () => {
    const completion = completionOf(owned('The Way of Kings', 'Brandon Sanderson'), input)
    expect(completion?.rating).toBe(StarRating(5))
    expect(completion?.note).toBe(input.note)
  })

  test('brings nothing to a book that already has it all, so a second import writes nothing', () => {
    const held = owned('The Way of Kings', 'Brandon Sanderson', {
      status: 'read',
      rating: StarRating(4),
      note: input.note,
    })
    expect(completionOf(held, input)).toBeUndefined()
  })
})
