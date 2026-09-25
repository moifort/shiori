import { describe, expect, test } from 'bun:test'
import type { AudibleItem, LastPosition } from 'audible-api-ts'
import { resolveGenreId } from 'audible-api-ts'
import {
  audibleLinksFor,
  audibleSearchUrlOf,
  bookFrom,
  boughtSince,
  importableFrom,
  listenedMinutesFor,
  listeningChangesFor,
  plainTextOf,
  purchaseDatesFor,
  readersDueForSync,
  seriesVolumesFor,
  shelfKeyOf,
  shelfKeysOf,
  statusOf,
} from '~/domain/audible/business-rules'
import type { AudibleAsin as AudibleAsinValue, AudibleConnection } from '~/domain/audible/types'
import { ListeningMinutes } from '~/domain/book/primitives'
import type { Book, BookId } from '~/domain/book/types'
import type { SeriesId, SeriesName, VolumeNumber } from '~/domain/series/types'
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

const aPosition = (overrides: Partial<LastPosition> = {}): LastPosition => ({
  asin: 'B002V1OF70',
  positionMs: 0,
  lastUpdatedAt: new Date('2026-09-16T20:55:15.357Z'),
  ...overrides,
})

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
    expect((book.subgenres ?? []).map(({ label }) => String(label))).toEqual(['Young Adult'])
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

  // The library's percent is stale: a title two hours in reports 0. Where the
  // player last stopped is what says the reader is in it.
  test('reads a title the player stopped well into as reading, whatever the percent', () => {
    const heard = aPosition({ positionMs: 138 * 60 * 1000 })
    expect(statusOf(anItem({ listeningStatus: { percentComplete: 0 } }), heard)).toBe('reading')
  })

  // A position of a minute or two is a title opened by curiosity, not a reading.
  test('leaves a title barely opened on the pile', () => {
    expect(statusOf(anItem(), aPosition({ positionMs: 4 * 60 * 1000 }))).toBe('to-read')
    expect(statusOf(anItem(), aPosition({ positionMs: 5 * 60 * 1000 }))).toBe('reading')
  })

  // Audible keeps a title "unfinished" when the reader stops during the
  // closing credits. Three minutes from the end is the end.
  test('reads a title the player stopped three minutes from the end as read', () => {
    const item = anItem({ durationMinutes: 600 })
    expect(statusOf(item, aPosition({ positionMs: 597 * 60 * 1000 }))).toBe('read')
    expect(statusOf(item, aPosition({ positionMs: 596 * 60 * 1000 }))).toBe('reading')
  })

  test('dates a title finished near its end on the day the player stopped', () => {
    const heard = aPosition({ positionMs: 599 * 60 * 1000 })
    const importable = importableFrom(anItem({ durationMinutes: 600 }), noneOwned, heard)

    expect(importable?.status).toBe('read')
    expect(importable?.finishedAt).toEqual(heard.lastUpdatedAt)
  })

  test('catalogues how far the player got, in whole minutes', () => {
    const heard = aPosition({ positionMs: 138 * 60 * 1000 + 59_000 })
    const importable = importableFrom(anItem(), noneOwned, heard)

    expect(importable?.listenedMinutes).toBe(ListeningMinutes(138))
    expect(bookFrom(importable as NonNullable<typeof importable>).listenedMinutes).toBe(
      ListeningMinutes(138),
    )
  })

  test('reads a finished listen as read whatever the position', () => {
    const item = anItem({ listeningStatus: { isFinished: true } })
    expect(statusOf(item, aPosition({ positionMs: 0 }))).toBe('read')
  })

  test('catalogues a title on the position the player saved', () => {
    const heard = aPosition({ positionMs: 138 * 60 * 1000 })
    expect(importableFrom(anItem(), noneOwned, heard)?.status).toBe('reading')
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

  // A title bought in 2019 and never opened belongs to 2019, not to the night
  // it was imported: the library is cut into months on that date.
  test('keeps the day Audible added the title, else the day it was bought', () => {
    const dateAdded = new Date('2019-06-01T00:00:00.000Z')
    const purchaseDate = new Date('2019-05-30T00:00:00.000Z')

    expect(importableFrom(anItem({ dateAdded, purchaseDate }), noneOwned)?.addedAt).toEqual(
      dateAdded,
    )
    expect(importableFrom(anItem({ purchaseDate }), noneOwned)?.addedAt).toEqual(purchaseDate)
    expect(importableFrom(anItem(), noneOwned)?.addedAt).toBeUndefined()
  })

  test('carries that day onto the book it writes', () => {
    const dateAdded = new Date('2019-06-01T00:00:00.000Z')
    const importable = importableFrom(anItem({ dateAdded }), noneOwned)

    expect(bookFrom(importable as NonNullable<typeof importable>).addedAt).toEqual(dateAdded)
  })
})

describe('the saga a title belongs to', () => {
  test('keys it to the saga heard, the one a scanned recording joins', () => {
    const importable = importableFrom(
      anItem({ series: { name: 'Chronique du tueur de roi', position: 1 } }),
      noneOwned,
    )

    expect(importable?.series).toMatchObject({
      id: 'chronique-du-tueur-de-roi--patrick-rothfuss--audio',
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

  // A novel too long for one recording is sold in parts, numbered 1.1 and 1.2:
  // both are volume 1, as the printed book they were cut from.
  test('files each part of a split novel under the volume it was cut from', () => {
    const volumeOf = (position: number) =>
      importableFrom(anItem({ series: { name: 'Chronique du Tueur de Roi', position } }), noneOwned)
        ?.series?.volume

    expect(volumeOf(1.1)).toBe(1 as VolumeNumber)
    expect(volumeOf(1.2)).toBe(1 as VolumeNumber)
    expect(volumeOf(2.1)).toBe(2 as VolumeNumber)
    expect(volumeOf(0.5)).toBeUndefined()
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

  // A book from before the status stamp has nothing of the reader's to weigh
  // against Audible: a title it says was never opened sends it back to the pile.
  test('sends an unstamped book Audible reports untouched back to the pile', () => {
    expect(listeningChangesFor([linked({ status: 'read' })], [anItem()])).toEqual([
      { bookId: bookId('book-1'), status: 'to-read', at: undefined },
    ])
  })

  test('ignores a book with no ASIN on it', () => {
    const items = [anItem({ listeningStatus: { isFinished: true } })]
    expect(listeningChangesFor([aBook()], items)).toEqual([])
  })

  // The sync learns of a start after the fact. The last time the player saved
  // a position is the closest date it has, and never later than tonight.
  test('starts a book on the day the player last heard it', () => {
    const heard = aPosition({ positionMs: 138 * 60 * 1000 })
    expect(listeningChangesFor([linked()], [anItem()], [heard])).toEqual([
      { bookId: bookId('book-1'), status: 'reading', at: heard.lastUpdatedAt },
    ])
  })

  test('leaves a book whose title has left the library alone', () => {
    expect(listeningChangesFor([linked({ status: 'read' })], [])).toEqual([])
  })

  test('finishes a book the player stopped three minutes from the end', () => {
    const heard = aPosition({ positionMs: 598 * 60 * 1000 })
    const items = [anItem({ durationMinutes: 600 })]

    expect(listeningChangesFor([linked({ status: 'reading' })], items, [heard])).toEqual([
      { bookId: bookId('book-1'), status: 'read', at: heard.lastUpdatedAt },
    ])
  })
})

describe('keeping the most recent word', () => {
  const droppedOn = new Date('2026-09-01T00:00:00.000Z')
  const dropped = (overrides: Partial<Book> = {}) =>
    aBook({
      audibleAsin: asin('B002V1OF70'),
      status: 'dropped',
      statusChangedAt: droppedOn,
      listenedMinutes: ListeningMinutes(138),
      ...overrides,
    })

  // What went wrong: a book the reader gave up on still sits half-heard in the
  // Audible library, and every night put it back on "reading".
  test('keeps a book the reader dropped after the player last moved', () => {
    const heard = aPosition({
      positionMs: 138 * 60 * 1000,
      lastUpdatedAt: new Date('2026-08-15T00:00:00.000Z'),
    })
    expect(listeningChangesFor([dropped()], [anItem()], [heard])).toEqual([])
  })

  test('keeps a status the reader set against a title Audible reports untouched', () => {
    expect(listeningChangesFor([dropped({ listenedMinutes: undefined })], [anItem()])).toEqual([])
  })

  test('starts the book again when the player went further overnight', () => {
    const heard = aPosition({
      positionMs: 200 * 60 * 1000,
      lastUpdatedAt: new Date('2026-08-15T00:00:00.000Z'),
    })
    expect(listeningChangesFor([dropped()], [anItem()], [heard])).toEqual([
      { bookId: bookId('book-1'), status: 'reading', at: heard.lastUpdatedAt },
    ])
  })

  test("follows Audible when its date is later than the reader's change", () => {
    const finishedAt = new Date('2026-09-10T00:00:00.000Z')
    const items = [anItem({ listeningStatus: { isFinished: true, finishedAt } })]
    expect(listeningChangesFor([dropped()], items)).toEqual([
      { bookId: bookId('book-1'), status: 'read', at: finishedAt },
    ])
  })

  test("keeps the reader's change when Audible finished the title before it", () => {
    const finishedAt = new Date('2026-08-10T00:00:00.000Z')
    const items = [anItem({ listeningStatus: { isFinished: true, finishedAt } })]
    expect(listeningChangesFor([dropped()], items)).toEqual([])
  })
})

describe('following how far the player got', () => {
  const linked = (overrides: Partial<Book> = {}) =>
    aBook({ audibleAsin: asin('B002V1OF70'), format: 'audiobook', ...overrides })

  test('records the minutes the player reached', () => {
    const heard = aPosition({ positionMs: 42 * 60 * 1000 })

    expect(listenedMinutesFor([linked()], [heard])).toEqual([
      { bookId: bookId('book-1'), listenedMinutes: ListeningMinutes(42) },
    ])
  })

  // A night the player did not move writes nothing.
  test('writes nothing when the minutes already agree', () => {
    const heard = aPosition({ positionMs: 42 * 60 * 1000 + 30_000 })
    expect(
      listenedMinutesFor([linked({ listenedMinutes: ListeningMinutes(42) })], [heard]),
    ).toEqual([])
  })

  test('ignores a book with no ASIN, and a title the player never opened', () => {
    expect(listenedMinutesFor([aBook()], [aPosition({ positionMs: 60_000 })])).toEqual([])
    expect(listenedMinutesFor([linked()], [])).toEqual([])
  })
})

describe('dating an import back to the day the title was bought', () => {
  const bought = new Date('2019-06-01T00:00:00.000Z')
  const imported = new Date('2026-09-22T08:00:00.000Z')
  const linked = (overrides: Partial<Book> = {}) =>
    aBook({ audibleAsin: asin('B002V1OF70'), addedAt: imported, ...overrides })

  test('moves a book stamped on the import day back to the purchase', () => {
    expect(purchaseDatesFor([linked()], [anItem({ dateAdded: bought })])).toEqual([
      { bookId: bookId('book-1'), addedAt: bought },
    ])
  })

  // The import stamped every date it did not know with one instant. Only those
  // move: a start the reader set themselves a week later is theirs to keep.
  test('moves the start and the status stamp only when they carry the same stamp', () => {
    const stamped = linked({ status: 'reading', startedAt: imported, statusChangedAt: imported })
    expect(purchaseDatesFor([stamped], [anItem({ dateAdded: bought })])).toEqual([
      { bookId: bookId('book-1'), addedAt: bought, startedAt: bought, statusChangedAt: bought },
    ])

    const later = new Date('2026-09-29T08:00:00.000Z')
    const own = linked({ status: 'reading', startedAt: later, statusChangedAt: later })
    expect(purchaseDatesFor([own], [anItem({ dateAdded: bought })])).toEqual([
      { bookId: bookId('book-1'), addedAt: bought },
    ])
  })

  test('falls back on the purchase date when Audible has no addition date', () => {
    expect(purchaseDatesFor([linked()], [anItem({ purchaseDate: bought })])).toEqual([
      { bookId: bookId('book-1'), addedAt: bought },
    ])
  })

  test('leaves a book already dated on or before the purchase alone', () => {
    expect(
      purchaseDatesFor([linked({ addedAt: bought })], [anItem({ dateAdded: bought })]),
    ).toEqual([])
    const earlier = new Date('2018-01-01T00:00:00.000Z')
    expect(
      purchaseDatesFor([linked({ addedAt: earlier })], [anItem({ dateAdded: bought })]),
    ).toEqual([])
  })

  test('leaves an unlinked book, and one Audible cannot date, alone', () => {
    expect(
      purchaseDatesFor([aBook({ addedAt: imported })], [anItem({ dateAdded: bought })]),
    ).toEqual([])
    expect(purchaseDatesFor([linked()], [anItem()])).toEqual([])
  })
})

describe('numbering an import made before split novels were numbered', () => {
  const saga = {
    id: 'chronique-du-tueur-de-roi--patrick-rothfuss--audio' as SeriesId,
    name: 'Chronique du Tueur de Roi' as SeriesName,
    kind: 'main' as const,
  }
  const linked = (overrides: Partial<Book> = {}) =>
    aBook({ audibleAsin: asin('B002V1OF70'), series: saga, ...overrides })
  const part = (position: number) =>
    anItem({ series: { name: 'Chronique du Tueur de Roi', position } })

  test('numbers a volume the import left without a rank', () => {
    expect(seriesVolumesFor([linked()], [part(1.2)])).toEqual([
      { bookId: bookId('book-1'), volume: 1 as VolumeNumber },
    ])
  })

  test('leaves a numbered volume, and a side story that has no rank, alone', () => {
    expect(
      seriesVolumesFor([linked({ series: { ...saga, volume: 3 as VolumeNumber } })], [part(1.2)]),
    ).toEqual([])
    expect(seriesVolumesFor([linked()], [part(4.5)])).toEqual([])
  })

  // The reader filed it in another saga by hand: Audible's numbering is not theirs.
  test('leaves a book filed under another saga alone', () => {
    const elsewhere = linked({ series: { ...saga, id: 'other--someone' as SeriesId } })
    expect(seriesVolumesFor([elsewhere], [part(1.2)])).toEqual([])
  })

  test('leaves an unlinked book, and one outside any saga, alone', () => {
    expect(seriesVolumesFor([aBook({ series: saga })], [part(1.2)])).toEqual([])
    expect(seriesVolumesFor([linked({ series: undefined })], [part(1.2)])).toEqual([])
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

describe('a search on the reader’s Audible store', () => {
  test('is on their marketplace, the title encoded', () => {
    expect(audibleSearchUrlOf('fr', 'Nous sommes Légion')).toBe(
      'https://www.audible.fr/search?keywords=Nous%20sommes%20L%C3%A9gion',
    )
  })
})
