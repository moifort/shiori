import { describe, expect, test } from 'bun:test'
import type { KindleTitle } from 'kindle-api-ts'
import { shelfKeyOf } from '~/domain/book/business-rules'
import { BookId } from '~/domain/book/primitives'
import type { Book, ReadingStatus } from '~/domain/book/types'
import {
  acquiredSince,
  bookFrom,
  importableFrom,
  isCataloguable,
  kindleLinksFor,
  readAsinsOf,
  readersDueForSync,
  readingChangesFor,
  sagaOf,
} from '~/domain/kindle/business-rules'
import { KindleAsin } from '~/domain/kindle/primitives'
import type { KindleConnection } from '~/domain/kindle/types'
import { AuthorName, BookTitle, UserId } from '~/domain/shared/primitives'

const aTitle = (overrides: Partial<KindleTitle> = {}): KindleTitle => ({
  asin: 'B0TESTAAA1',
  title: 'Le Nom du vent',
  authors: ['Patrick Rothfuss'],
  coverUrl: 'https://m.media-amazon.com/images/I/91cover.jpg',
  readStatus: 'UNKNOWN',
  originType: 'Purchase',
  category: 'KindleEBook',
  acquiredAt: new Date('2026-03-01T10:00:00.000Z'),
  ...overrides,
})

const aBook = (overrides: Partial<Book> = {}): Book => ({
  id: BookId('book-1'),
  userId: UserId('reader'),
  title: BookTitle('Le Nom du vent'),
  authors: [AuthorName('Patrick Rothfuss')],
  format: 'ebook',
  subgenres: [],
  narrators: [],
  status: 'to-read',
  hidden: false,
  addedAt: new Date('2026-01-01'),
  ...overrides,
})

describe('isCataloguable', () => {
  test('keeps what was bought, borrowed or shared', () => {
    for (const originType of ['Purchase', 'Prime', 'KindleUnlimited', 'Sharing']) {
      expect(isCataloguable(aTitle({ originType }))).toBe(true)
    }
  })

  // 88 of the 165 titles of the first account probed were dictionaries.
  test('leaves out the dictionaries and the free samples', () => {
    expect(isCataloguable(aTitle({ originType: 'KindleDictionary' }))).toBe(false)
    expect(isCataloguable(aTitle({ originType: 'Sample' }))).toBe(false)
    expect(isCataloguable(aTitle({ category: 'KindleEBookSample' }))).toBe(false)
  })
})

describe('sagaOf', () => {
  test.each([
    ['Powerless (Tome 3) - Fearless', 'Fearless', 'Powerless', 3],
    ['Powerless, Tome 2 : Reckless', 'Reckless', 'Powerless', 2],
    ['Powerless - tome 1 - Powerless', 'Powerless', 'Powerless', 1],
    ['Boys of Tommen #5 : Taming 7', 'Taming 7', 'Boys of Tommen', 5],
    [
      'Le Nom du vent (Chronique du tueur de roi, tome 1)',
      'Le Nom du vent',
      'Chronique du tueur de roi',
      1,
    ],
    ['Fearless (Powerless Book 3)', 'Fearless', 'Powerless', 3],
    ['Powerless (Tome 3)', 'Powerless (Tome 3)', 'Powerless', 3],
    ['Dune - Livre 2', 'Dune - Livre 2', 'Dune', 2],
    ['Le Sorceleur T.4 : Le Temps du mépris', 'Le Temps du mépris', 'Le Sorceleur', 4],
  ])('reads %p as %p, volume of %p', (raw, title, series, volume) => {
    expect(sagaOf(raw)).toEqual({ title, series: { name: series, volume } })
  })

  test('drops the edition Amazon appends to a translation', () => {
    expect(sagaOf('Powerless (Tome 3) - Fearless (French Edition)')).toEqual({
      title: 'Fearless',
      series: { name: 'Powerless', volume: 3 },
    })
    expect(sagaOf('Les Misérables (Édition française)')).toEqual({ title: 'Les Misérables' })
  })

  // A guessed saga files a book on a shelf nothing else shares.
  test('keeps no saga for a title no pattern recognizes', () => {
    expect(sagaOf('1984')).toEqual({ title: '1984' })
    expect(sagaOf('Les Tomes perdus')).toEqual({ title: 'Les Tomes perdus' })
    expect(sagaOf('Intégrale Tomes 1 à 3')).toEqual({ title: 'Intégrale Tomes 1 à 3' })
  })
})

describe('importableFrom', () => {
  test('maps a bought title onto the book it would be', () => {
    const importable = importableFrom(aTitle({ title: 'Powerless (Tome 3) - Fearless' }), new Set())

    expect(importable).toMatchObject({
      asin: 'B0TESTAAA1',
      title: 'Fearless',
      authors: ['Patrick Rothfuss'],
      coverUrl: 'https://m.media-amazon.com/images/I/91cover.jpg',
      series: { id: 'powerless--patrick-rothfuss', name: 'Powerless', volume: 3, kind: 'main' },
      status: 'to-read',
      alreadyInLibrary: false,
    })
    expect(importable?.addedAt).toEqual(new Date('2026-03-01T10:00:00.000Z'))
    expect(importable?.finishedAt).toBeUndefined()
  })

  // Amazon says a book was read, never when.
  test('dates a read title finished on the day it was acquired', () => {
    const importable = importableFrom(aTitle({ readStatus: 'READ' }), new Set())

    expect(importable?.status).toBe('read')
    expect(importable?.finishedAt).toEqual(new Date('2026-03-01T10:00:00.000Z'))
  })

  test('marks a title already on the shelf, whatever the edition', () => {
    const owned = new Set([shelfKeyOf('Le Nom du vent', 'Patrick Rothfuss')])

    expect(importableFrom(aTitle(), owned)?.alreadyInLibrary).toBe(true)
  })

  test('keeps no saga without an author to key it on', () => {
    const importable = importableFrom(aTitle({ title: 'Dune - Livre 2', authors: [] }), new Set())

    expect(importable?.series).toBeUndefined()
  })

  test('offers nothing for a dictionary, a sample, or a bad identifier', () => {
    expect(importableFrom(aTitle({ originType: 'KindleDictionary' }), new Set())).toBeUndefined()
    expect(importableFrom(aTitle({ category: 'KindleEBookSample' }), new Set())).toBeUndefined()
    expect(importableFrom(aTitle({ asin: 'nope' }), new Set())).toBeUndefined()
  })
})

describe('bookFrom', () => {
  test('catalogues an ebook carrying its Kindle title', () => {
    const importable = importableFrom(aTitle({ readStatus: 'READ' }), new Set())
    if (!importable) throw new Error('expected an importable book')

    expect(bookFrom(importable)).toMatchObject({
      title: 'Le Nom du vent',
      format: 'ebook',
      status: 'read',
      kindleAsin: 'B0TESTAAA1',
      publishedCoverUrl: 'https://m.media-amazon.com/images/I/91cover.jpg',
    })
  })
})

describe('kindleLinksFor', () => {
  test('links an ebook catalogued before the link, by shelf key', () => {
    const links = kindleLinksFor([aBook()], [aTitle()])

    expect(links).toEqual([{ bookId: BookId('book-1'), kindleAsin: KindleAsin('B0TESTAAA1') }])
  })

  test('matches on the title the saga was read out of', () => {
    const links = kindleLinksFor(
      [aBook({ title: BookTitle('Fearless') })],
      [aTitle({ title: 'Powerless (Tome 3) - Fearless' })],
    )

    expect(links).toHaveLength(1)
  })

  // A printed copy or a recording of the same story is another object.
  test('never links a book in another format, or one already linked', () => {
    expect(kindleLinksFor([aBook({ format: 'book' })], [aTitle()])).toEqual([])
    expect(kindleLinksFor([aBook({ kindleAsin: KindleAsin('B0OTHERAAA') })], [aTitle()])).toEqual(
      [],
    )
  })

  test('gives an ASIN to one book only', () => {
    const links = kindleLinksFor(
      [aBook({ id: BookId('first') }), aBook({ id: BookId('second') })],
      [aTitle()],
    )

    expect(links.map((link) => link.bookId)).toEqual([BookId('first')])
  })

  test('ignores titles that are no book', () => {
    expect(kindleLinksFor([aBook()], [aTitle({ originType: 'KindleDictionary' })])).toEqual([])
  })
})

describe('readingChangesFor', () => {
  const linked = (status: ReadingStatus, id = 'book-1') =>
    aBook({ id: BookId(id), status, kindleAsin: KindleAsin('B0TESTAAA1') })
  const read = [aTitle({ readStatus: 'READ' })]

  test('moves a book Amazon newly reports read', () => {
    expect(readingChangesFor([linked('reading')], read, [])).toEqual([BookId('book-1')])
    expect(readingChangesFor([linked('dropped')], read, [])).toEqual([BookId('book-1')])
  })

  // READ never goes away on Amazon: a reader starting the book again must not
  // be put back on "read" every night.
  test('moves nothing Amazon already reported read at the last pass', () => {
    expect(readingChangesFor([linked('reading')], read, [KindleAsin('B0TESTAAA1')])).toEqual([])
  })

  test('never moves a book back, nor one already read', () => {
    expect(readingChangesFor([linked('read')], read, [])).toEqual([])
    expect(readingChangesFor([linked('read')], [aTitle()], [KindleAsin('B0TESTAAA1')])).toEqual([])
  })

  test('on a first pass, leaves a book the reader dropped where it is', () => {
    expect(readingChangesFor([linked('dropped')], read, undefined)).toEqual([])
    expect(readingChangesFor([linked('to-read')], read, undefined)).toEqual([BookId('book-1')])
  })

  test('touches no book without a Kindle title', () => {
    expect(readingChangesFor([aBook({ status: 'reading' })], read, [])).toEqual([])
  })
})

describe('readAsinsOf', () => {
  test('lists the titles reported read', () => {
    expect(readAsinsOf([aTitle({ readStatus: 'READ' }), aTitle({ asin: 'B0TESTBBB2' })])).toEqual([
      KindleAsin('B0TESTAAA1'),
    ])
  })
})

describe('acquiredSince', () => {
  const cutoff = new Date('2026-06-01T00:00:00.000Z')

  test('keeps only what was acquired after the cutoff', () => {
    const titles = [
      aTitle({ asin: 'B0OLDAAAA1', acquiredAt: new Date('2026-05-01') }),
      aTitle({ asin: 'B0NEWAAAA1', acquiredAt: new Date('2026-07-01') }),
      aTitle({ asin: 'B0NODATEA1', acquiredAt: undefined }),
    ]

    expect(acquiredSince(titles, cutoff).map((title) => title.asin)).toEqual(['B0NEWAAAA1'])
    expect(acquiredSince(titles, undefined)).toHaveLength(3)
  })
})

describe('readersDueForSync', () => {
  const connection = (userId: string, account?: Partial<KindleConnection['account']>) =>
    ({
      userId: UserId(userId),
      account: account && {
        marketplace: 'fr',
        credentials: 'sealed',
        connectedAt: new Date(),
        ...account,
      },
    }) as KindleConnection

  test('the least recently synced first, without those who turned it off', () => {
    const readers = readersDueForSync([
      connection('recent', { lastImportedAt: new Date('2026-09-30') }),
      connection('off', { autoSync: false }),
      connection('pending'),
      connection('never', {}),
      connection('older', { lastImportedAt: new Date('2026-09-01') }),
    ])

    expect(readers).toEqual([UserId('never'), UserId('older'), UserId('recent')])
  })
})
