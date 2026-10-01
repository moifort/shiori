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

const { KindleCommand } = await import('~/domain/kindle/command')
const { KindleUseCase } = await import('~/domain/kindle/use-case')
const { KindleQuery } = await import('~/domain/kindle/query')
const { KindleAsin } = await import('~/domain/kindle/primitives')
const { BookQuery } = await import('~/domain/book/query')
const { BookCommand } = await import('~/domain/book/command')
const { BookTitle, AuthorName } = await import('~/domain/shared/primitives')
const { ReadingNote } = await import('~/domain/book/primitives')

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
})

const connect = async (who: UserId = reader) => {
  await KindleCommand.startLogin(who, 'fr', NOW)
  await KindleCommand.completeLogin(who, 'the-code', NOW)
}

const anEbook = (title: string, author = 'Lauren Roberts') =>
  BookCommand.add(reader, {
    title: BookTitle(title),
    authors: [AuthorName(author)],
    format: 'ebook',
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
  test('catalogues them as ebooks in their saga, with their cover and their status', async () => {
    await connect()
    titles = [aTitle({ readStatus: 'READ' }), aTitle({ asin: 'B0TESTBBB2', title: 'Autre' })]

    const imported = await KindleUseCase.importBooks(reader, [KindleAsin('B0TESTAAA1')], NOW)

    expect(imported).toHaveLength(1)
    const [book] = await BookQuery.all(reader)
    expect(book).toMatchObject({
      title: 'Fearless',
      format: 'ebook',
      status: 'read',
      kindleAsin: 'B0TESTAAA1',
      publishedCoverUrl: 'https://m.media-amazon.com/images/I/91cover.jpg',
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
