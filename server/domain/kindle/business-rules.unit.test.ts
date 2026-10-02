import { describe, expect, test } from 'bun:test'
import type { KindleTitle } from 'kindle-api-ts'
import { type Shelf, shelfKeyOf } from '~/domain/book/business-rules'
import { BookId } from '~/domain/book/primitives'
import type { Book, ReadingStatus } from '~/domain/book/types'
import {
  acquiredSince,
  bookFrom,
  carriesVolume,
  editionLanguageOf,
  importableFrom,
  isCataloguable,
  kindleLinksFor,
  readAsinsOf,
  readersDueForSync,
  readingChangesFor,
  readTitleFrom,
  sagaOf,
  splitOf,
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

// Every title below is one of the first library synced, on amazon.fr.
describe('editionLanguageOf', () => {
  test('reads the language a title names', () => {
    expect(editionLanguageOf('Zodiac Academy 9: Restless Stars (English Edition)', undefined)).toBe(
      'en',
    )
    expect(editionLanguageOf('Enchantra (Édition Française): Wicked Games Tome 2', undefined)).toBe(
      'fr',
    )
    expect(
      editionLanguageOf(
        'Zodiac Academy 3: Le Jugement (Zodiac Academy (Édition Française))',
        undefined,
      ),
    ).toBe('fr')
    expect(
      editionLanguageOf('Iron Flame - Version française: The Empyrean Tome 2', undefined),
    ).toBe('fr')
  })

  // The title of 44 of the 50 titles probed said nothing; their sort key did.
  test('falls back on the language the sort key ends on', () => {
    expect(editionLanguageOf('Phantasma: Wicked Games Tome 1', 'phantasma french edition')).toBe(
      'fr',
    )
    expect(editionLanguageOf('La femme de ménage', 'femme de ménage french edition, la')).toBe('fr')
  })

  test('takes no language from an edition that names none', () => {
    expect(editionLanguageOf('Captive - Tome 1 (édition reliée)', undefined)).toBeUndefined()
    expect(editionLanguageOf('1984', '1984')).toBeUndefined()
    expect(editionLanguageOf('Le Nom du vent', 'nom du vent klingon edition, le')).toBeUndefined()
  })
})

describe('carriesVolume', () => {
  test('finds the number however the publisher wrote it', () => {
    expect(carriesVolume("Goldfinch: La saga d'Auren - T06", 6)).toBe(true)
    expect(carriesVolume('King of Scars, Tome 02: Le règne des loups', 2)).toBe(true)
    expect(carriesVolume('Boys of Tommen #5 : Taming 7', 5)).toBe(true)
    expect(carriesVolume("Un Palais d'épines et de roses T3.5: Un Palais de glace", 3.5)).toBe(true)
  })

  test('finds no number inside another', () => {
    expect(carriesVolume("Un Palais d'épines et de roses T3.5: Un Palais de glace", 3)).toBe(false)
    expect(carriesVolume('1984', 1)).toBe(false)
    expect(carriesVolume('La femme de ménage voit tout', 2)).toBe(false)
  })
})

describe('readTitleFrom', () => {
  const READ_AT = new Date('2026-10-02T09:00:00.000Z')

  test('keeps the title, the saga and a number the Amazon title carries', () => {
    const item = aTitle({ title: 'Iron Flame - Version française: The Empyrean Tome 2' })

    expect(
      readTitleFrom(
        item,
        { title: ' Iron Flame ', seriesName: 'The Empyrean', volumeNumber: 2 },
        READ_AT,
      ),
    ).toEqual({
      asin: KindleAsin('B0TESTAAA1'),
      amazonTitle: 'Iron Flame - Version française: The Empyrean Tome 2',
      title: BookTitle('Iron Flame'),
      seriesName: 'The Empyrean',
      volume: 2,
      readAt: READ_AT,
    })
  })

  // Three volumes of one saga came back numbered wrong on the first library.
  test('drops a number the model worked out on its own', () => {
    const item = aTitle({ title: 'La femme de ménage voit tout' })
    const read = readTitleFrom(
      item,
      { title: 'La femme de ménage voit tout', seriesName: 'La femme de ménage', volumeNumber: 2 },
      READ_AT,
    )

    expect(read?.seriesName).toBe('La femme de ménage')
    expect(read?.volume).toBeUndefined()
  })

  test('reads nothing from an answer with no title', () => {
    expect(readTitleFrom(aTitle(), { title: '  ', seriesName: null }, READ_AT)).toBeUndefined()
  })
})

describe('splitOf', () => {
  const read = {
    asin: KindleAsin('B0TESTAAA1'),
    amazonTitle: 'Phantasma: Wicked Games Tome 1',
    title: BookTitle('Phantasma'),
    seriesName: 'Wicked Games',
    volume: 1,
    readAt: new Date(),
  }

  test("takes the model's reading of this very title", () => {
    expect(
      splitOf(aTitle({ title: 'Phantasma: Wicked Games Tome 1' }), new Map([[read.asin, read]])),
    ).toEqual({ title: 'Phantasma', series: { name: 'Wicked Games', volume: 1 } })
  })

  test('reads a renamed title by its patterns again', () => {
    expect(
      splitOf(aTitle({ title: 'Wicked Games (Tome 1) - Phantasma' }), new Map([[read.asin, read]])),
    ).toEqual({ title: 'Phantasma', series: { name: 'Wicked Games', volume: 1 } })
    expect(splitOf(aTitle({ title: 'Phantasma' }), new Map([[read.asin, read]]))).toEqual({
      title: 'Phantasma',
    })
  })
})

describe('importableFrom', () => {
  test('maps a bought title onto the book it would be', () => {
    const importable = importableFrom(aTitle({ title: 'Powerless (Tome 3) - Fearless' }), new Map())

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
    const importable = importableFrom(aTitle({ readStatus: 'READ' }), new Map())

    expect(importable?.status).toBe('read')
    expect(importable?.finishedAt).toEqual(new Date('2026-03-01T10:00:00.000Z'))
  })

  test('marks a title already on the shelf, whatever the edition', () => {
    const owned: Shelf = new Map([[shelfKeyOf('Le Nom du vent', 'Patrick Rothfuss'), [{}]]])

    expect(importableFrom(aTitle(), owned)?.alreadyInLibrary).toBe(true)
  })

  test('keeps no saga without an author to key it on', () => {
    const importable = importableFrom(aTitle({ title: 'Dune - Livre 2', authors: [] }), new Map())

    expect(importable?.series).toBeUndefined()
  })

  test('carries the language of the edition', () => {
    const importable = importableFrom(
      aTitle({ title: 'Fearless', sortableTitle: 'fearless french edition' }),
      new Map(),
    )

    expect(importable?.language).toBe('fr')
  })

  test('offers nothing for a dictionary, a sample, or a bad identifier', () => {
    expect(importableFrom(aTitle({ originType: 'KindleDictionary' }), new Map())).toBeUndefined()
    expect(importableFrom(aTitle({ category: 'KindleEBookSample' }), new Map())).toBeUndefined()
    expect(importableFrom(aTitle({ asin: 'nope' }), new Map())).toBeUndefined()
  })
})

describe('bookFrom', () => {
  test('catalogues an ebook carrying its Kindle title', () => {
    const importable = importableFrom(
      aTitle({ readStatus: 'READ', sortableTitle: 'nom du vent french edition, le' }),
      new Map(),
    )
    if (!importable) throw new Error('expected an importable book')

    expect(bookFrom(importable)).toMatchObject({
      title: 'Le Nom du vent',
      format: 'ebook',
      status: 'read',
      kindleAsin: 'B0TESTAAA1',
      language: 'fr',
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
