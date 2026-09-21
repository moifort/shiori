import { describe, expect, test } from 'bun:test'
import type { AudibleItem } from 'audible-api-ts'
import { resolveGenreId } from 'audible-api-ts'
import {
  audibleLinksFor,
  bookFrom,
  boughtSince,
  importableFrom,
  listeningChangesFor,
  plainTextOf,
  readersDueForSync,
  shelfKeyOf,
  shelfKeysOf,
  statusOf,
} from '~/domain/audible/business-rules'
import type { AudibleAsin as AudibleAsinValue, AudibleConnection } from '~/domain/audible/types'
import { ListeningMinutes } from '~/domain/book/primitives'
import type { Book, BookId } from '~/domain/book/types'
import type { BookTitle, UserId } from '~/domain/shared/types'

const anItem = (overrides: Partial<AudibleItem> = {}): AudibleItem =>
  ({
    asin: 'B002V1OF70',
    title: 'Le Nom du vent',
    authors: ['Patrick Rothfuss'],
    narrators: ['Bernard Gabay'],
    durationMinutes: 1770,
    categories: [],
    keywords: [],
    relationships: [],
    isAdultProduct: false,
    productImages: {},
    socialMediaImages: {},
    ...overrides,
  }) as AudibleItem

const noneOwned = new Set<string>()

describe('reading one Audible title', () => {
  test('catalogues it with what Audible knows', () => {
    const importable = importableFrom(
      anItem({ publisher: 'Audiolib', isbn: '9780756404741' }),
      noneOwned,
    )

    expect(importable).toMatchObject({
      asin: 'B002V1OF70',
      title: 'Le Nom du vent',
      authors: ['Patrick Rothfuss'],
      narrators: ['Bernard Gabay'],
      durationMinutes: 1770,
      publisher: 'Audiolib',
      isbn13: '9780756404741',
      alreadyInLibrary: false,
    })
  })

  // The only source there is for it: a scanned cover does not say how long the
  // recording runs, and the dashboard counts hours listened from this field.
  test('carries the running time onto the book', () => {
    const importable = importableFrom(anItem(), noneOwned)

    if (!importable) throw new Error('unreachable')
    expect(bookFrom(importable).durationMinutes).toBe(ListeningMinutes(1770))
  })

  test('leaves the running time empty when Audible reports none', () => {
    const importable = importableFrom(anItem({ durationMinutes: 0 }), noneOwned)

    if (!importable) throw new Error('unreachable')
    expect(bookFrom(importable).durationMinutes).toBeUndefined()
  })

  test('always catalogues it as an audiobook', () => {
    const importable = importableFrom(anItem(), noneOwned)

    if (!importable) throw new Error('unreachable')
    expect(bookFrom(importable).format).toBe('audiobook')
  })

  // Audible's release date is the date the recording came out. Filling the year
  // the WORK first appeared with it would date Dune to 2018 on the book screen.
  test('leaves the first publication year empty rather than dating the recording', () => {
    const importable = importableFrom(anItem({ releaseDate: new Date('2018-03-01') }), noneOwned)

    if (!importable) throw new Error('unreachable')
    expect(bookFrom(importable).firstPublishedIn).toBeUndefined()
  })

  // A single bad field must not sink an otherwise good record, exactly as with a
  // scan: the brands are what keep an invented ISBN out of the database.
  test('drops a field that does not validate, and keeps the rest', () => {
    const importable = importableFrom(anItem({ isbn: '1234567890123', publisher: '' }), noneOwned)

    expect(importable).toMatchObject({ title: 'Le Nom du vent' })
    expect(importable?.isbn13).toBeUndefined()
    expect(importable?.publisher).toBeUndefined()
  })

  test('skips a row with no usable title', () => {
    expect(importableFrom(anItem({ title: '' }), noneOwned)).toBeUndefined()
  })

  test('skips a row whose identifier is not an ASIN', () => {
    expect(importableFrom(anItem({ asin: 'not-an-asin' }), noneOwned)).toBeUndefined()
  })

  test('takes the largest cover Audible offers', () => {
    const importable = importableFrom(
      anItem({
        coverUrl: 'https://m.media-amazon.com/images/I/small.jpg',
        productImages: {
          '500': 'https://m.media-amazon.com/images/I/500.jpg',
          '900': 'https://m.media-amazon.com/images/I/900.jpg',
        },
      }),
      noneOwned,
    )

    expect(String(importable?.coverUrl)).toBe('https://m.media-amazon.com/images/I/900.jpg')
  })

  test('refuses a cover served over plain HTTP, which iOS would never draw', () => {
    const importable = importableFrom(
      anItem({ productImages: { '900': 'http://m.media-amazon.com/images/I/900.jpg' } }),
      noneOwned,
    )

    expect(importable?.coverUrl).toBeUndefined()
  })
})

describe('who a title is credited to', () => {
  // Audible files every contributor under `authors` and tags the role inside the
  // name. Left alone, a translated novel shows "Danusia Stok - translator" on the
  // book screen as if she had written it.
  test('drops the translator, who did not write it', () => {
    const importable = importableFrom(
      anItem({ authors: ['Andrzej Sapkowski', 'Danusia Stok - translator'] }),
      noneOwned,
    )

    expect(importable?.authors.map(String)).toEqual(['Andrzej Sapkowski'])
  })

  test('drops the role in whichever language the store tags it', () => {
    const importable = importableFrom(
      anItem({ authors: ['Andrzej Sapkowski', 'Lea Voinson - traduction'] }),
      noneOwned,
    )

    expect(importable?.authors.map(String)).toEqual(['Andrzej Sapkowski'])
  })

  // A title Audible credits to its translator alone would otherwise lose its
  // author line AND its place in a saga, which is keyed on the first author.
  test('keeps the translator, stripped, when nobody else is credited', () => {
    const importable = importableFrom(anItem({ authors: ['Danusia Stok - translator'] }), noneOwned)

    expect(importable?.authors.map(String)).toEqual(['Danusia Stok'])
  })

  test('leaves an author whose name merely ends in a word about translation', () => {
    const importable = importableFrom(anItem({ authors: ['Jean Traducteur'] }), noneOwned)

    expect(importable?.authors.map(String)).toEqual(['Jean Traducteur'])
  })

  test('keys the shelf on the author, never on the translator', () => {
    const owned = new Set([shelfKeyOf('Le Dernier Vœu', 'Andrzej Sapkowski')])
    const importable = importableFrom(
      anItem({
        title: 'Le Dernier Vœu',
        authors: ['Andrzej Sapkowski', 'Lea Voinson - translator'],
      }),
      owned,
    )

    expect(importable?.alreadyInLibrary).toBe(true)
  })
})

describe('the shelf a title is filed under', () => {
  test("carries Audible's shelf onto the book as a Shiori genre", () => {
    const importable = importableFrom(
      anItem({
        categories: [
          {
            root: 'Genres',
            categories: [{ id: resolveGenreId('fantasy', 'fr'), name: 'Fantasy' }],
          },
        ],
      }),
      noneOwned,
    )

    if (!importable) throw new Error('unreachable')
    expect(bookFrom(importable).genre).toBe('fantasy')
  })

  // The reader then picks one on the book screen, as they do for a book typed in
  // by hand. Better no genre than a wrong one.
  test('leaves the genre empty when the shelf means nothing here', () => {
    const importable = importableFrom(anItem(), noneOwned)

    if (!importable) throw new Error('unreachable')
    expect(bookFrom(importable).genre).toBeUndefined()
    expect(bookFrom(importable).subgenres).toEqual([])
  })

  // An audience is not a genre, but it is exactly what a subgenre is for — so it
  // reaches the book rather than being dropped, alongside the genre the rung
  // below it named.
  test('carries an audience onto the book as a subgenre, beside its genre', () => {
    const importable = importableFrom(
      anItem({
        categories: [
          {
            root: 'Genres',
            categories: [
              { id: resolveGenreId('young-adult', 'fr'), name: 'Jeunes adultes' },
              { id: resolveGenreId('young-adult/thriller', 'fr'), name: 'Thriller' },
            ],
          },
        ],
      }),
      noneOwned,
    )

    if (!importable) throw new Error('unreachable')
    const book = bookFrom(importable)
    expect(book.genre).toBe('thriller')
    expect((book.subgenres ?? []).map(String)).toEqual(['Young Adult'])
  })
})

describe('where the reader stands in a title', () => {
  test('reads a finished listen as read', () => {
    expect(statusOf(anItem({ listeningStatus: { isFinished: true } }))).toBe('read')
  })

  test('reads a started listen as reading', () => {
    expect(statusOf(anItem({ listeningStatus: { percentComplete: 5 } }))).toBe('reading')
  })

  test('leaves an untouched purchase on the pile', () => {
    expect(statusOf(anItem())).toBe('to-read')
  })

  // Importing a decade of listening must not stamp every title with today's
  // date: the dashboard counts books finished this month.
  test('keeps the date the listening actually ended', () => {
    const finishedAt = new Date('2022-04-01T00:00:00.000Z')

    const importable = importableFrom(
      anItem({ listeningStatus: { isFinished: true, finishedAt } }),
      noneOwned,
    )

    expect(importable?.finishedAt).toEqual(finishedAt)
    expect(bookFrom(importable as NonNullable<typeof importable>).finishedAt).toEqual(finishedAt)
  })

  test('keeps no finishing date for a book still being listened to', () => {
    const importable = importableFrom(
      anItem({ listeningStatus: { percentComplete: 30, finishedAt: new Date('2022-04-01') } }),
      noneOwned,
    )

    expect(importable?.finishedAt).toBeUndefined()
  })
})

describe('the saga a title belongs to', () => {
  test('keys it the way a scan keys it, so both land in one catalogue', () => {
    const importable = importableFrom(
      anItem({ series: { name: 'Chronique du tueur de roi', position: 1 } }),
      noneOwned,
    )

    expect(importable?.series).toMatchObject({
      id: 'chronique-du-tueur-de-roi--patrick-rothfuss',
      name: 'Chronique du tueur de roi',
      volume: 1,
      kind: 'main',
    })
  })

  // Audible numbers side stories 4.5. A volume number is a rank on the spine, so
  // the membership keeps the saga and loses only the rank.
  test('keeps a half-numbered side story in the saga, without a rank', () => {
    const importable = importableFrom(
      anItem({ series: { name: 'Primal Hunter', position: 4.5 } }),
      noneOwned,
    )

    expect(String(importable?.series?.name)).toBe('Primal Hunter')
    expect(importable?.series?.volume).toBeUndefined()
  })

  // Without an author there is no stable key, and an id nothing else shares would
  // make a saga nobody can ever rejoin.
  test('drops the saga when nothing names an author', () => {
    const importable = importableFrom(
      anItem({ authors: [], series: { name: 'Chronique du tueur de roi' } }),
      noneOwned,
    )

    expect(importable?.series).toBeUndefined()
  })
})

describe('an Audible summary', () => {
  test('reaches the book as text rather than as markup', () => {
    const importable = importableFrom(
      anItem({ summary: '<p>Kvothe raconte sa vie.</p><p>Il n&#39;omet rien.</p>' }),
      noneOwned,
    )

    expect(String(importable?.synopsis)).toBe("Kvothe raconte sa vie.\n\nIl n'omet rien.")
  })

  test('falls back on the merchandising blurb when there is no summary', () => {
    const importable = importableFrom(
      anItem({ merchandisingSummary: '<b>Un chef-d’œuvre.</b>' }),
      noneOwned,
    )

    expect(String(importable?.synopsis)).toBe('Un chef-d’œuvre.')
  })

  // A synopsis is capped at 4000 characters; a truncated one beats losing it.
  test('truncates rather than dropping a summary that runs long', () => {
    const importable = importableFrom(anItem({ summary: 'a'.repeat(5000) }), noneOwned)

    expect(importable?.synopsis).toHaveLength(4000)
  })

  test('leaves the synopsis empty when Audible has nothing to say', () => {
    expect(plainTextOf(undefined)).toBeUndefined()
    expect(importableFrom(anItem(), noneOwned)?.synopsis).toBeUndefined()
  })
})

describe('telling what the reader already has', () => {
  const owned = [
    { title: 'Le Nom du vent', authors: ['Patrick Rothfuss'] },
    { title: 'Dune', authors: [] },
  ] as unknown as Book[]

  test('recognizes a title already on the shelves', () => {
    expect(importableFrom(anItem(), shelfKeysOf(owned))?.alreadyInLibrary).toBe(true)
  })

  // The match is on the text, not on an identifier kept on the book: a title
  // scanned from the printed edition has no ASIN and must still be recognized.
  test('folds accents, case and punctuation so two spellings meet', () => {
    expect(shelfKeyOf('L’Assassin royal', 'Robin Hobb')).toBe(
      shelfKeyOf('Assassin Royal', 'robin hobb'),
    )
  })

  test('leaves a title the reader does not have unmatched', () => {
    const importable = importableFrom(anItem({ title: 'La Peur du sage' }), shelfKeysOf(owned))

    expect(importable?.alreadyInLibrary).toBe(false)
  })

  test('does not confuse two books that only share a title', () => {
    const importable = importableFrom(
      anItem({ title: 'Dune', authors: ['Frank Herbert'] }),
      shelfKeysOf(owned),
    )

    expect(importable?.alreadyInLibrary).toBe(false)
  })
})

const aBook = (overrides: Partial<Book> = {}): Book =>
  ({
    id: 'book-1',
    userId: 'reader-1',
    title: 'Le Nom du vent',
    authors: ['Patrick Rothfuss'],
    format: 'audiobook',
    narrators: [],
    subgenres: [],
    status: 'to-read',
    hidden: false,
    addedAt: new Date('2026-01-01T00:00:00.000Z'),
    ...overrides,
  }) as Book

// The brands these rules speak in. Cast at the edge of the test rather than run
// through the constructors: what is under test is the matching, not the parsing.
const bookId = (value: string) => value as BookId
const asin = (value: string) => value as AudibleAsinValue
const title = (value: string) => value as BookTitle

describe('linking a catalogued book to its Audible title', () => {
  test('matches an import made before the ASIN was kept', () => {
    expect(audibleLinksFor([aBook()], [anItem()])).toEqual([
      { bookId: bookId('book-1'), audibleAsin: asin('B002V1OF70') },
    ])
  })

  test('leaves a book that already carries one alone', () => {
    const linked = aBook({ audibleAsin: asin('B002V1OF70') })
    expect(audibleLinksFor([linked], [anItem()])).toEqual([])
  })

  // The whole point of the link: a novel the reader scanned from the printed
  // edition must never start taking orders from Audible because a recording of
  // it exists under the same title.
  test('never links anything but an audiobook', () => {
    expect(audibleLinksFor([aBook({ format: 'book' })], [anItem()])).toEqual([])
  })

  test('does not hand one ASIN to two records of the same story', () => {
    const books = [aBook(), aBook({ id: bookId('book-2') })]
    expect(audibleLinksFor(books, [anItem()])).toEqual([
      { bookId: bookId('book-1'), audibleAsin: asin('B002V1OF70') },
    ])
  })

  test('leaves a book Audible does not carry unlinked', () => {
    expect(audibleLinksFor([aBook({ title: title('Dune') })], [anItem()])).toEqual([])
  })
})

describe('following the listening', () => {
  const linked = (overrides: Partial<Book> = {}) =>
    aBook({ audibleAsin: asin('B002V1OF70'), ...overrides })

  test('marks a book read on the date Audible finished it', () => {
    const finishedAt = new Date('2026-04-01T00:00:00.000Z')
    const items = [anItem({ listeningStatus: { isFinished: true, finishedAt } })]

    expect(listeningChangesFor([linked()], items)).toEqual([
      { bookId: bookId('book-1'), status: 'read', at: finishedAt },
    ])
  })

  test('writes nothing when the status already agrees', () => {
    const items = [anItem({ listeningStatus: { isFinished: true } })]
    expect(listeningChangesFor([linked({ status: 'read' })], items)).toEqual([])
  })

  // Audible is authoritative in both directions, which is what was asked for: a
  // title it says was never opened sends the book back to the pile.
  test('sends a book Audible reports untouched back to the pile', () => {
    expect(listeningChangesFor([linked({ status: 'read' })], [anItem()])).toEqual([
      { bookId: bookId('book-1'), status: 'to-read', at: undefined },
    ])
  })

  test('ignores a book with no ASIN on it', () => {
    const items = [anItem({ listeningStatus: { isFinished: true } })]
    expect(listeningChangesFor([aBook()], items)).toEqual([])
  })

  test('leaves a book whose title has left the library alone', () => {
    expect(listeningChangesFor([linked({ status: 'read' })], [])).toEqual([])
  })
})

describe('what counts as bought since the last pass', () => {
  const lastPass = new Date('2026-09-01T00:00:00.000Z')

  test('keeps a purchase made since', () => {
    const fresh = anItem({ purchaseDate: new Date('2026-09-15T00:00:00.000Z') })
    expect(boughtSince([fresh], lastPass)).toHaveLength(1)
  })

  // A title on offer when the reader last picked was declined by not being
  // ticked. Importing it tonight would overrule them.
  test('leaves behind what the reader already declined', () => {
    const old = anItem({ purchaseDate: new Date('2026-08-01T00:00:00.000Z') })
    expect(boughtSince([old], lastPass)).toEqual([])
  })

  test('falls back on the date it was added to the library', () => {
    const added = anItem({ dateAdded: new Date('2026-09-15T00:00:00.000Z') })
    expect(boughtSince([added], lastPass)).toHaveLength(1)
  })

  test('leaves out a title Amazon dates neither way', () => {
    expect(boughtSince([anItem()], lastPass)).toEqual([])
  })

  test('takes the whole library for a reader who never imported', () => {
    expect(boughtSince([anItem()], undefined)).toHaveLength(1)
  })
})

describe('choosing whose library to sync', () => {
  const aConnection = (userId: string, account?: Partial<AudibleConnection['account']>) =>
    ({
      userId,
      account: account && {
        marketplace: 'fr',
        credentials: 'sealed',
        connectedAt: new Date(),
        ...account,
      },
    }) as AudibleConnection

  test('skips a reader who turned the sync off', () => {
    expect(readersDueForSync([aConnection('reader-1', { autoSync: false })])).toEqual([])
  })

  // The setting did not exist when these connections were made, and they are
  // precisely the ones the sync was built for.
  test('takes a connection made before the setting existed', () => {
    expect(readersDueForSync([aConnection('reader-1', {})])).toEqual(['reader-1' as UserId])
  })

  test('skips a sign-in still in flight', () => {
    expect(readersDueForSync([aConnection('reader-1')])).toEqual([])
  })

  // What makes the time budget safe to hit: whoever was cut off is first in line
  // the next night.
  test('puts the staleest reader first, and the never-synced ahead of all', () => {
    const order = readersDueForSync([
      aConnection('recent', { lastImportedAt: new Date('2026-09-19T00:00:00.000Z') }),
      aConnection('stale', { lastImportedAt: new Date('2026-09-01T00:00:00.000Z') }),
      aConnection('never', {}),
    ])
    expect(order).toEqual(['never', 'stale', 'recent'] as UserId[])
  })
})
