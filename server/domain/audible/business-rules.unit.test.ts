import { describe, expect, test } from 'bun:test'
import type { AudibleItem } from 'audible-api-ts'
import {
  bookFrom,
  importableFrom,
  plainTextOf,
  shelfKeyOf,
  shelfKeysOf,
  statusOf,
} from '~/domain/audible/business-rules'
import type { Book } from '~/domain/book/types'

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
