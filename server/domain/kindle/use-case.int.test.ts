import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { randomBytes } from 'node:crypto'
import type { KindleTitle } from 'kindle-api-ts'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore, startFakeRequest } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
const kindleKey = randomBytes(32).toString('base64')
mock.module('~/system/config', () => ({ config: () => ({ kindleKey }) }))

/** What Amazon would answer, and how often it was asked: an import must make
 *  one trip, not one per title. Refusals are handed out one per call, oldest
 *  first — how one reader's deregistered device is staged without disturbing
 *  another's. */
let titles: KindleTitle[] = []
const libraryCalls: unknown[] = []
const libraryRefusals: (Error | undefined)[] = []

mock.module('~/domain/kindle/infrastructure/kindle-api', () => ({
  login: async (marketplace: string) => ({
    loginUrl: `https://www.amazon.${marketplace}/ap/signin`,
    session: { codeVerifier: 'verifier-1', serial: 'SERIAL1', locale: marketplace, createdAt: NOW },
    cookies: [],
  }),
  register: async () => ({
    refreshToken: 'Atnr|the-refresh-token',
    adpToken: '{enc:token}',
    devicePrivateKey: 'key',
    serial: 'SERIAL1',
    locale: 'fr',
  }),
  library: async (credentials: unknown) => {
    libraryCalls.push(credentials)
    const refusal = libraryRefusals.shift()
    if (refusal) throw refusal
    return titles
  },
  landingUrlFor: (marketplace: string) => `https://www.amazon.${marketplace}/ap/maplanding`,
}))

/** Stands in for the model that splits Kindle titles: what it was asked, and
 *  what it answers — nothing by default, so the patterns read the titles. A
 *  queued failure is thrown by the next call. */
const titleCalls: { asin: string; title: string }[][] = []
let titleAnswers: Record<string, { title: string; seriesName?: string; volumeNumber?: number }> = {}
const titleFailures: Error[] = []
mock.module('~/domain/kindle/infrastructure/title-reader', () => ({
  TITLES_PER_CALL: 40,
  readTitles: async (batch: { asin: string; title: string }[]) => {
    titleCalls.push(batch)
    const failure = titleFailures.shift()
    if (failure) throw failure
    return {
      usage: { promptTokens: 10, outputTokens: 5, thinkingTokens: 0, searches: 0 },
      value: {
        books: batch.flatMap(({ asin }) =>
          titleAnswers[asin]
            ? [{ asin, seriesName: null, volumeNumber: null, ...titleAnswers[asin] }]
            : [],
        ),
      },
    }
  },
}))

const { KindleCommand } = await import('~/domain/kindle/command')
const { KindleUseCase } = await import('~/domain/kindle/use-case')
const { KindleQuery } = await import('~/domain/kindle/query')
const { KindleAsin } = await import('~/domain/kindle/primitives')
const { BookQuery } = await import('~/domain/book/query')
const { BookCommand } = await import('~/domain/book/command')
const { BookTitle, AuthorName } = await import('~/domain/shared/primitives')
const { CoverUrl, ReadingNote } = await import('~/domain/book/primitives')

const reader = 'reader-1' as UserId
const NOW = new Date('2026-10-01T10:00:00.000Z')
const NIGHT = new Date('2026-10-02T04:30:00.000Z')

const aTitle = (overrides: Partial<KindleTitle> = {}): KindleTitle => ({
  asin: 'B0TESTAAA1',
  title: 'Powerless (Tome 3) - Fearless',
  authors: ['Lauren Roberts'],
  coverUrl: 'https://m.media-amazon.com/images/I/91cover.jpg',
  readStatus: 'UNKNOWN',
  originType: 'Purchase',
  category: 'KindleEBook',
  acquiredAt: new Date('2026-09-14T10:00:00.000Z'),
  ...overrides,
})

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
  titles = []
  libraryCalls.length = 0
  libraryRefusals.length = 0
  titleCalls.length = 0
  titleAnswers = {}
  titleFailures.length = 0
})

const connect = async (who: UserId = reader) => {
  await KindleCommand.startLogin(who, 'fr', NOW)
  await KindleCommand.completeLogin(who, 'the-code', NOW)
}

const anEbook = (title: string, author = 'Lauren Roberts') =>
  BookCommand.add(reader, {
    title: BookTitle(title),
    authors: [AuthorName(author)],
    media: ['digital'],
  })

const aPaperback = (title: string, author = 'Lauren Roberts') =>
  BookCommand.add(reader, {
    title: BookTitle(title),
    authors: [AuthorName(author)],
    publishedCoverUrl: CoverUrl('https://covers.openlibrary.org/b/isbn/fearless.jpg'),
  })

describe('listing what could be imported', () => {
  test('says so when no library is connected, without calling Amazon', async () => {
    expect(await KindleUseCase.importableBooks(reader)).toBe('not-connected')
    expect(libraryCalls).toHaveLength(0)
  })

  // Credentials sealed with a key that is gone can never be opened again.
  test('drops a connection it can no longer decrypt, and asks to connect again', async () => {
    await connect()
    fake.seed('kindle-connections', reader, {
      userId: reader,
      account: { marketplace: 'fr', credentials: 'v1.aaaa.bbbb.cccc', connectedAt: NOW },
    })
    startFakeRequest()

    expect(await KindleUseCase.importableBooks(reader)).toBe('not-connected')
    expect(libraryCalls).toHaveLength(0)
    expect(fake.data('kindle-connections', reader)).toBeNull()
  })

  test('proposes the books, never the dictionaries nor the samples, and saves nothing', async () => {
    await connect()
    titles = [
      aTitle(),
      aTitle({ asin: 'B0TESTDICT', title: 'Dictionnaire', originType: 'KindleDictionary' }),
      aTitle({ asin: 'B0TESTSAMP', title: 'Extrait', category: 'KindleEBookSample' }),
    ]

    const importable = await KindleUseCase.importableBooks(reader)

    expect(Array.isArray(importable) && importable.map((book) => String(book.title))).toEqual([
      'Fearless',
    ])
    expect(await BookQuery.all(reader)).toHaveLength(0)
  })
})

describe('importing the ticked titles', () => {
  test('catalogues them held on a screen, in their saga, with their cover and status', async () => {
    await connect()
    titles = [aTitle({ readStatus: 'READ' }), aTitle({ asin: 'B0TESTBBB2', title: 'Autre' })]

    const imported = await KindleUseCase.importBooks(reader, [KindleAsin('B0TESTAAA1')], NOW)

    expect(imported).toHaveLength(1)
    const [book] = await BookQuery.all(reader)
    expect(book).toMatchObject({
      title: 'Fearless',
      format: 'book',
      media: ['digital'],
      status: 'read',
      kindleAsin: 'B0TESTAAA1',
      kindleCoverUrl: 'https://m.media-amazon.com/images/I/91cover.jpg',
      series: { name: 'Powerless', volume: 3 },
    })
    // Dated on the acquisition, never on import night.
    expect(book.addedAt).toEqual(new Date('2026-09-14T10:00:00.000Z'))
    expect(book.finishedAt).toEqual(new Date('2026-09-14T10:00:00.000Z'))
    expect(libraryCalls).toHaveLength(1)
  })

  test('creates no duplicate when the same list is imported twice', async () => {
    await connect()
    titles = [aTitle()]

    await KindleUseCase.importBooks(reader, [KindleAsin('B0TESTAAA1')], NOW)
    startFakeRequest()
    const second = await KindleUseCase.importBooks(reader, [KindleAsin('B0TESTAAA1')], NOW)

    expect(second).toEqual([])
    expect(await BookQuery.all(reader)).toHaveLength(1)
  })

  test('joins a title held on paper to its record rather than doubling it', async () => {
    await connect()
    const paperback = await aPaperback('Fearless')
    titles = [aTitle()]

    expect(await KindleUseCase.importBooks(reader, [KindleAsin('B0TESTAAA1')], NOW)).toEqual([])
    expect(await BookQuery.all(reader)).toEqual([
      expect.objectContaining({
        id: paperback.id,
        media: ['print', 'digital'],
        kindleAsin: 'B0TESTAAA1',
      }),
    ])
  })

  test('matches an ASIN the library does not hold to nothing', async () => {
    await connect()
    titles = [aTitle()]

    expect(await KindleUseCase.importBooks(reader, [KindleAsin('B0NOTOWNED')], NOW)).toEqual([])
  })

  // The nightly pass must not catalogue, unasked, what the reader left unticked.
  test('moves the cutoff, and leaves the read set to the first pass', async () => {
    await connect()
    titles = [aTitle({ readStatus: 'READ' })]

    await KindleUseCase.importBooks(reader, [], NOW)

    const account = await KindleQuery.accountOf(reader)
    expect(account?.lastImportedAt).toEqual(NOW)
    expect(account?.readAsins).toBeUndefined()
  })
})

describe('reading the titles with the model', () => {
  const ironFlame = aTitle({
    asin: 'B0IRONFLAM',
    title: 'Iron Flame - Version française: The Empyrean Tome 2',
    authors: ['Rebecca Yarros'],
  })

  test('catalogues the title alone, in the saga the model names', async () => {
    await connect()
    titles = [ironFlame]
    titleAnswers = {
      B0IRONFLAM: { title: 'Iron Flame', seriesName: 'The Empyrean', volumeNumber: 2 },
    }

    await KindleUseCase.importBooks(reader, [KindleAsin('B0IRONFLAM')], NOW)

    const [book] = await BookQuery.all(reader)
    expect(book).toMatchObject({
      title: 'Iron Flame',
      series: { name: 'The Empyrean', volume: 2 },
    })
  })

  // The order of a saga's volumes is where the model was wrong.
  test('keeps the saga but not a number the Amazon title does not carry', async () => {
    await connect()
    titles = [aTitle({ asin: 'B0MENAGE02', title: 'La femme de ménage voit tout' })]
    titleAnswers = {
      B0MENAGE02: {
        title: 'La femme de ménage voit tout',
        seriesName: 'La femme de ménage',
        volumeNumber: 2,
      },
    }

    const [importable] = (await KindleUseCase.importableBooks(reader)) as { series?: unknown }[]

    expect(importable?.series).toMatchObject({ name: 'La femme de ménage', volume: undefined })
  })

  test('reads a title once for every reader, and again only once Amazon renames it', async () => {
    await connect()
    titles = [ironFlame]
    titleAnswers = { B0IRONFLAM: { title: 'Iron Flame', seriesName: 'The Empyrean' } }

    await KindleUseCase.importableBooks(reader)
    await KindleUseCase.importBooks(reader, [KindleAsin('B0IRONFLAM')], NOW)
    expect(titleCalls).toHaveLength(1)
    expect(fake.data('kindle-titles', 'B0IRONFLAM')).toMatchObject({ title: 'Iron Flame' })

    titles = [{ ...ironFlame, title: 'Iron Flame: The Empyrean, T2' }]
    await KindleUseCase.importableBooks(reader)
    expect(titleCalls).toHaveLength(2)
  })

  test('falls back on the patterns when the model fails, and keeps nothing', async () => {
    await connect()
    titles = [aTitle()]
    titleFailures.push(new Error('Gemini unavailable'))

    const importable = await KindleUseCase.importableBooks(reader)

    expect(Array.isArray(importable) && importable.map((book) => String(book.title))).toEqual([
      'Fearless',
    ])
    expect(fake.data('kindle-titles', 'B0TESTAAA1')).toBeNull()
  })

  test('asks forty titles a call', async () => {
    await connect()
    titles = Array.from({ length: 41 }, (_, index) =>
      aTitle({ asin: `B0TEST${String(index).padStart(4, '0')}`, title: `Livre ${index}` }),
    )

    await KindleUseCase.importableBooks(reader)

    expect(titleCalls.map((batch) => batch.length)).toEqual([40, 1])
  })
})

describe('a nightly pass', () => {
  test('catalogues what was acquired since the last pass, and only that', async () => {
    await connect()
    await KindleCommand.recordPass(reader, [], NOW)
    titles = [
      aTitle({ asin: 'B0OLDAAAA1', title: 'Ancien', acquiredAt: new Date('2026-09-01') }),
      aTitle({
        asin: 'B0NEWAAAA1',
        title: 'Nouveau',
        acquiredAt: new Date('2026-10-01T20:00:00Z'),
      }),
    ]
    startFakeRequest()

    expect(await KindleUseCase.syncLibrary(reader, NIGHT)).toEqual({
      linked: 0,
      moved: 0,
      imported: 1,
    })
    expect((await BookQuery.all(reader)).map((book) => String(book.title))).toEqual(['Nouveau'])
  })

  test('on a first pass, catalogues the whole library', async () => {
    await connect()
    titles = [aTitle(), aTitle({ asin: 'B0TESTBBB2', title: 'Autre' })]

    expect(await KindleUseCase.syncLibrary(reader, NIGHT)).toMatchObject({ imported: 2 })
  })

  test('moves a book Amazon newly reports read, dated tonight, and says so', async () => {
    await connect()
    titles = [aTitle()]
    await KindleUseCase.importBooks(reader, [KindleAsin('B0TESTAAA1')], NOW)
    await KindleUseCase.syncLibrary(reader, NOW)
    titles = [aTitle({ readStatus: 'READ' })]
    startFakeRequest()

    expect(await KindleUseCase.syncLibrary(reader, NIGHT)).toMatchObject({ moved: 1 })
    const [book] = await BookQuery.all(reader)
    expect(book.status).toBe('read')
    expect(book.finishedAt).toEqual(NIGHT)
  })

  // READ never goes away on Amazon: a reader reading the book again must not be
  // put back on "read" every night.
  test('does not move a book again that Amazon already reported read', async () => {
    await connect()
    titles = [aTitle({ readStatus: 'READ' })]
    await KindleUseCase.importBooks(reader, [KindleAsin('B0TESTAAA1')], NOW)
    await KindleUseCase.syncLibrary(reader, NOW)
    const [book] = await BookQuery.all(reader)
    await BookCommand.setStatus(reader, book.id, 'reading', NOW)
    startFakeRequest()

    expect(await KindleUseCase.syncLibrary(reader, NIGHT)).toMatchObject({ moved: 0 })
    expect((await BookQuery.all(reader))[0].status).toBe('reading')
  })

  // The data export's books, all to-read stubs, follow the reading once linked.
  test('links an ebook catalogued before the link, and moves it in the same pass', async () => {
    await connect()
    await anEbook('Fearless')
    titles = [aTitle({ readStatus: 'READ' })]

    expect(await KindleUseCase.syncLibrary(reader, NIGHT)).toEqual({
      linked: 1,
      moved: 1,
      imported: 0,
    })
    const [book] = await BookQuery.all(reader)
    expect(book).toMatchObject({ kindleAsin: 'B0TESTAAA1', status: 'read' })
  })

  // Paper or screen, one book: the paperback found on the Kindle is held both
  // ways, drawn under the Kindle cover, and followed like any Kindle title.
  test('links a paperback the reader also holds on the Kindle, and moves it', async () => {
    await connect()
    await aPaperback('Fearless')
    titles = [aTitle({ readStatus: 'READ' })]

    expect(await KindleUseCase.syncLibrary(reader, NIGHT)).toEqual({
      linked: 1,
      moved: 1,
      imported: 0,
    })
    const [book] = await BookQuery.all(reader)
    expect(book).toMatchObject({
      media: ['print', 'digital'],
      kindleAsin: 'B0TESTAAA1',
      kindleCoverUrl: 'https://m.media-amazon.com/images/I/91cover.jpg',
      status: 'read',
    })
    expect((await BookQuery.byId(reader, book.id))?.coverUrl).toBe(
      CoverUrl('https://m.media-amazon.com/images/I/91cover.jpg'),
    )
  })

  // A pair compared on an earlier night is not compared again: the old titles
  // are read only once a book of their author has been written since.
  test('reads the old titles again only for a book written since the last pass', async () => {
    await connect()
    const paperback = await BookCommand.add(
      reader,
      { title: BookTitle('Fearless'), authors: [AuthorName('Lauren Roberts')] },
      new Date('2026-09-01T10:00:00.000Z'),
    )
    const lastPass = new Date('2026-10-03T02:30:00.000Z')
    const tonight = new Date('2026-10-04T02:30:00.000Z')
    await KindleCommand.recordPass(reader, [], lastPass)
    titles = [aTitle({ acquiredAt: new Date('2026-08-01T10:00:00.000Z') })]

    expect(await KindleUseCase.syncLibrary(reader, tonight)).toMatchObject({ linked: 0 })
    expect(titleCalls).toHaveLength(0)

    await BookCommand.setStatus(
      reader,
      paperback.id,
      'reading',
      new Date(tonight.getTime() + 60_000),
    )
    startFakeRequest()
    const later = new Date(tonight.getTime() + 3_600_000)
    expect(await KindleUseCase.syncLibrary(reader, later)).toMatchObject({ linked: 1 })
    expect(titleCalls.flat().map(({ asin }) => asin)).toEqual(['B0TESTAAA1'])
  })

  test('never touches the note of a book it moves', async () => {
    await connect()
    const book = await anEbook('Fearless')
    await BookCommand.annotate(reader, book.id, ReadingNote('Relu en vacances'))
    titles = [aTitle({ readStatus: 'READ' })]

    await KindleUseCase.syncLibrary(reader, NIGHT)

    expect((await BookQuery.all(reader))[0].note).toBe(ReadingNote('Relu en vacances'))
  })

  test('is skipped for a reader who turned it off, unless they ask', async () => {
    await connect()
    await KindleCommand.setAutoSync(reader, false)
    titles = [aTitle()]

    expect(await KindleUseCase.syncLibrary(reader, NIGHT)).toBe('sync-disabled')
    expect(libraryCalls).toHaveLength(0)
    expect(await KindleUseCase.syncLibrary(reader, NIGHT, true)).toMatchObject({ imported: 1 })
  })

  test('reads the shelf once and the connection once', async () => {
    await connect()
    await KindleCommand.recordPass(reader, [], NOW)
    titles = [aTitle({ acquiredAt: new Date('2026-09-01') })]
    startFakeRequest()
    const before = { docs: fake.docReads, queries: fake.queryReads }

    await KindleUseCase.syncLibrary(reader, NIGHT)

    expect(fake.queryReads - before.queries).toBe(1)
    expect(fake.docReads - before.docs).toBe(1)
  })
})

describe('the nightly run', () => {
  test('steps over a reader Amazon refuses, and records it on their connection', async () => {
    const other = 'reader-2' as UserId
    await connect()
    await connect(other)
    titles = [aTitle()]
    libraryRefusals.push(new Error('Cookie exchange failed: 401'))

    const run = await KindleUseCase.syncEveryReader(120_000, Date.now())

    expect(run).toEqual({ synced: 1, failed: 1, deferred: 0 })
    const accounts = [await KindleQuery.accountOf(reader), await KindleQuery.accountOf(other)]
    expect(accounts.filter((account) => account?.lastSyncFailedAt)).toHaveLength(1)
  })

  test('leaves for tomorrow the readers past its budget', async () => {
    await connect()

    expect(await KindleUseCase.syncEveryReader(0, Date.now() - 1)).toEqual({
      synced: 0,
      failed: 0,
      deferred: 1,
    })
  })
})
