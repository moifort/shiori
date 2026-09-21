import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { randomBytes } from 'node:crypto'
import type { AudibleItem } from 'audible-api-ts'
import type { AudibleAsin } from '~/domain/audible/types'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
// One key for the whole file: config() is read on every seal and every open, and
// a fresh key per call would make a sealed value unreadable a line later.
const audibleKey = randomBytes(32).toString('base64')
mock.module('~/system/config', () => ({ config: () => ({ audibleKey }) }))

/** What Amazon would answer, and what it was handed. `libraryCalls` is how the
 *  read budget against a third party is asserted: an import must make one trip,
 *  not one per title. */
let items: AudibleItem[] = []
const libraryCalls: unknown[] = []
/** Refusals to hand out, one per call, oldest first. Empty means Amazon
 *  answers — which is how one reader's revoked device is staged without
 *  disturbing the other's. */
const libraryRefusals: (Error | undefined)[] = []

mock.module('~/domain/audible/infrastructure/audible-api', () => ({
  login: async (marketplace: string) => ({
    loginUrl: `https://www.amazon.${marketplace}/ap/signin`,
    session: { codeVerifier: 'verifier-1', serial: 'SERIAL1', marketplace, createdAt: NOW },
    cookies: [],
  }),
  register: async () => ({
    accessToken: 'access-1',
    refreshToken: 'Atnr|the-refresh-token',
    adpToken: '{enc:token}',
    devicePrivateKey: 'key',
    serial: 'SERIAL1',
    locale: 'fr',
    expiresAt: new Date('2026-09-19T11:00:00.000Z'),
  }),
  // Answers with a rotated access token, as the real client does once it has
  // refreshed an expired one.
  library: async (credentials: unknown) => {
    libraryCalls.push(credentials)
    const refusal = libraryRefusals.shift()
    if (refusal) throw refusal
    return {
      items,
      credentials: {
        accessToken: 'access-2',
        refreshToken: 'Atnr|the-refresh-token',
        adpToken: '{enc:token}',
        devicePrivateKey: 'key',
        serial: 'SERIAL1',
        locale: 'fr',
        expiresAt: new Date('2026-09-19T12:00:00.000Z'),
      },
    }
  },
  landingUrlOf: (marketplace: string) => `https://www.amazon.${marketplace}/ap/maplanding`,
}))

const { AudibleCommand } = await import('~/domain/audible/command')
const { AudibleUseCase } = await import('~/domain/audible/use-case')
const { AudibleQuery } = await import('~/domain/audible/query')
const { BookQuery } = await import('~/domain/book/query')
const { BookCommand } = await import('~/domain/book/command')
const { BookTitle, AuthorName } = await import('~/domain/shared/primitives')

const reader = 'reader-1' as UserId
const NOW = new Date('2026-09-19T10:00:00.000Z')

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

const asin = (value: string) => value as AudibleAsin

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
  items = []
  libraryCalls.length = 0
  libraryRefusals.length = 0
})

const connect = async (who: UserId = reader) => {
  await AudibleCommand.startLogin(who, 'fr', NOW)
  await AudibleCommand.completeLogin(who, 'the-code', NOW)
}

describe('listing what could be imported', () => {
  test('says so when no account is connected', async () => {
    expect(await AudibleUseCase.importableBooks(reader)).toBe('not-connected')
    expect(libraryCalls).toHaveLength(0)
  })

  // The sealing key can be rotated — it was, once, because the first one leaked
  // into a public build log. Credentials sealed with a key that is gone cannot
  // be opened again and never will be, so the connection is dropped rather than
  // left as something the reader can retry forever.
  test('drops a connection it can no longer decrypt, and asks to connect again', async () => {
    await connect()
    fake.seed('audible-connections', reader, {
      userId: reader,
      account: {
        marketplace: 'fr',
        credentials: 'v1.aaaa.bbbb.cccc',
        connectedAt: NOW,
      },
    })

    expect(await AudibleUseCase.importableBooks(reader)).toBe('not-connected')
    expect(libraryCalls).toHaveLength(0)
    expect(fake.data('audible-connections', reader)).toBeNull()
  })

  test('proposes the library without saving anything', async () => {
    await connect()
    items = [anItem(), anItem({ asin: 'B00X57B4KE', title: 'La Peur du sage' })]

    const importable = await AudibleUseCase.importableBooks(reader)

    expect(importable).toHaveLength(2)
    expect(await BookQuery.all(reader)).toHaveLength(0)
  })

  // A title the reader already has is returned rather than hidden: the picker
  // shows it ticked off, which reads as "we know" instead of "we lost one".
  test('marks a title the reader already has', async () => {
    await connect()
    await BookCommand.add(reader, {
      title: BookTitle('Le Nom du vent'),
      authors: [AuthorName('Patrick Rothfuss')],
    })
    items = [anItem(), anItem({ asin: 'B00X57B4KE', title: 'La Peur du sage' })]

    const importable = await AudibleUseCase.importableBooks(reader)

    if (importable === 'not-connected') throw new Error('unreachable')
    expect(importable.map((book) => [String(book.title), book.alreadyInLibrary])).toEqual([
      ['Le Nom du vent', true],
      ['La Peur du sage', false],
    ])
  })

  test('skips a row with nothing to catalogue rather than failing the list', async () => {
    await connect()
    items = [anItem({ title: '' }), anItem({ asin: 'B00X57B4KE', title: 'La Peur du sage' })]

    const importable = await AudibleUseCase.importableBooks(reader)

    expect(importable).toHaveLength(1)
  })
})

describe('importing the ticked titles', () => {
  test('catalogues only what was ticked', async () => {
    await connect()
    items = [anItem(), anItem({ asin: 'B00X57B4KE', title: 'La Peur du sage' })]

    const imported = await AudibleUseCase.importBooks(reader, [asin('B00X57B4KE')])

    expect(imported).toHaveLength(1)
    expect((await BookQuery.all(reader)).map((book) => String(book.title))).toEqual([
      'La Peur du sage',
    ])
  })

  test('catalogues them as audiobooks, with what Audible knows', async () => {
    await connect()
    items = [
      anItem({
        publisher: 'Audiolib',
        series: { name: 'Chronique du tueur de roi', position: 1 },
        listeningStatus: { isFinished: true, finishedAt: new Date('2022-04-01T00:00:00.000Z') },
      }),
    ]

    await AudibleUseCase.importBooks(reader, [asin('B002V1OF70')])

    const [book] = await BookQuery.all(reader)
    expect(book).toMatchObject({
      title: 'Le Nom du vent',
      format: 'audiobook',
      publisher: 'Audiolib',
      status: 'read',
      finishedAt: new Date('2022-04-01T00:00:00.000Z'),
      series: { id: 'chronique-du-tueur-de-roi--patrick-rothfuss', volume: 1, kind: 'main' },
    })
  })

  // Importing a decade of listening must not date every title today: the
  // dashboard counts what was finished this month, and it would count all of it.
  test('never stamps a start later than the finish it was given', async () => {
    await connect()
    items = [
      anItem({
        listeningStatus: { isFinished: true, finishedAt: new Date('2022-04-01T00:00:00.000Z') },
      }),
    ]

    await AudibleUseCase.importBooks(reader, [asin('B002V1OF70')])

    const [book] = await BookQuery.all(reader)
    expect(book?.startedAt).toEqual(new Date('2022-04-01T00:00:00.000Z'))
  })

  // The client sends identifiers, every stored field comes from the source. An
  // identifier the reader's library does not hold must simply match nothing.
  test('ignores an identifier the library does not hold', async () => {
    await connect()
    items = [anItem()]

    const imported = await AudibleUseCase.importBooks(reader, [asin('B0000000ZZ')])

    expect(imported).toHaveLength(0)
    expect(await BookQuery.all(reader)).toHaveLength(0)
  })

  test('creates no duplicate when the same import is run twice', async () => {
    await connect()
    items = [anItem()]

    await AudibleUseCase.importBooks(reader, [asin('B002V1OF70')])
    const second = await AudibleUseCase.importBooks(reader, [asin('B002V1OF70')])

    expect(second).toHaveLength(0)
    expect(await BookQuery.all(reader)).toHaveLength(1)
  })

  test('says so when no account is connected, and writes nothing', async () => {
    expect(await AudibleUseCase.importBooks(reader, [asin('B002V1OF70')])).toBe('not-connected')
    expect(await BookQuery.all(reader)).toHaveLength(0)
  })

  test('reads the Audible library once, whatever the number of titles', async () => {
    await connect()
    items = Array.from({ length: 30 }, (_, index) =>
      anItem({ asin: `B00000${String(index).padStart(4, '0')}`, title: `Title ${index}` }),
    )

    await AudibleUseCase.importBooks(
      reader,
      items.map((item) => asin(item.asin)),
    )

    expect(libraryCalls).toHaveLength(1)
    expect(await BookQuery.all(reader)).toHaveLength(30)
  })

  test('notes when the library was last imported', async () => {
    await connect()
    items = [anItem()]

    await AudibleUseCase.importBooks(reader, [asin('B002V1OF70')])

    expect((await AudibleQuery.accountOf(reader))?.lastImportedAt).toBeInstanceOf(Date)
  })

  // The access token is short-lived and the client refreshes it on its own. Not
  // keeping what came back means paying for that refresh on every import.
  test('keeps the credentials the client rotated, still sealed', async () => {
    await connect()
    items = [anItem()]

    await AudibleUseCase.importBooks(reader, [asin('B002V1OF70')])
    await AudibleUseCase.importableBooks(reader)

    expect(libraryCalls[1]).toMatchObject({ accessToken: 'access-2' })
    expect(JSON.stringify(fake.data('audible-connections', reader))).not.toContain('access-2')
  })

  // The dashboard is derived data. It must never look fresh over books it does
  // not count, so it is marked stale before the first one lands.
  test('leaves the dashboard counting the imported books', async () => {
    await connect()
    items = [
      anItem({
        listeningStatus: { isFinished: true, finishedAt: new Date('2026-09-01T00:00:00.000Z') },
      }),
    ]

    await AudibleUseCase.importBooks(reader, [asin('B002V1OF70')])

    expect(fake.data('analytics', reader)).toMatchObject({ stale: false })
  })
})

describe('the nightly sync', () => {
  const LATER = new Date('2026-09-26T04:00:00.000Z')

  test('says so when no account is connected', async () => {
    expect(await AudibleUseCase.syncLibrary(reader, LATER)).toBe('not-connected')
    expect(libraryCalls).toHaveLength(0)
  })

  // Turning it off must cost nothing at all — not a trip to Amazon, not a
  // rotated token. The check comes before the call for that reason.
  test('does not even call Amazon for a reader who turned it off', async () => {
    await connect()
    await AudibleCommand.setAutoSync(reader, false)

    expect(await AudibleUseCase.syncLibrary(reader, LATER)).toBe('sync-disabled')
    expect(libraryCalls).toHaveLength(0)
  })

  test('catalogues a title bought since the last pass and leaves an older one alone', async () => {
    await connect()
    await AudibleCommand.recordImport(reader, NOW)
    items = [
      anItem({ purchaseDate: new Date('2026-09-22T00:00:00.000Z') }),
      anItem({
        asin: 'B00X57B4KE',
        title: 'La Peur du sage',
        purchaseDate: new Date('2026-08-01T00:00:00.000Z'),
      }),
    ]

    expect(await AudibleUseCase.syncLibrary(reader, LATER)).toEqual({
      linked: 0,
      moved: 0,
      imported: 1,
    })
    expect((await BookQuery.all(reader)).map((book) => String(book.title))).toEqual([
      'Le Nom du vent',
    ])
  })

  // The first pass has to adopt the library the reader imported by hand, or
  // those books sit outside the sync forever. It links and acts in one go.
  test('links an import made before the ASIN was kept, and follows it the same night', async () => {
    await connect()
    await AudibleCommand.recordImport(reader, NOW)
    const finishedAt = new Date('2026-09-24T00:00:00.000Z')
    await BookCommand.add(reader, {
      title: BookTitle('Le Nom du vent'),
      authors: [AuthorName('Patrick Rothfuss')],
      format: 'audiobook',
    })
    items = [anItem({ listeningStatus: { isFinished: true, finishedAt } })]

    expect(await AudibleUseCase.syncLibrary(reader, LATER)).toEqual({
      linked: 1,
      moved: 1,
      imported: 0,
    })
    const [book] = await BookQuery.all(reader)
    expect(book?.audibleAsin).toBe(asin('B002V1OF70'))
    expect(book?.status).toBe('read')
    // Audible's own date, not tonight's: a title finished last week must not
    // land on the night the sync heard about it.
    expect(book?.finishedAt).toEqual(finishedAt)
  })

  test('leaves a book catalogued from the printed edition untouched', async () => {
    await connect()
    await AudibleCommand.recordImport(reader, NOW)
    await BookCommand.add(reader, {
      title: BookTitle('Le Nom du vent'),
      authors: [AuthorName('Patrick Rothfuss')],
    })
    items = [anItem({ listeningStatus: { isFinished: true } })]

    expect(await AudibleUseCase.syncLibrary(reader, LATER)).toEqual({
      linked: 0,
      moved: 0,
      imported: 0,
    })
    const [book] = await BookQuery.all(reader)
    expect(book?.status).toBe('to-read')
  })

  test('moves the cutoff forward, so the next pass finds nothing to redo', async () => {
    await connect()
    await AudibleCommand.recordImport(reader, NOW)
    items = [anItem({ purchaseDate: new Date('2026-09-22T00:00:00.000Z') })]

    await AudibleUseCase.syncLibrary(reader, LATER)
    expect((await AudibleQuery.accountOf(reader))?.lastImportedAt).toEqual(LATER)
    expect(await AudibleUseCase.syncLibrary(reader, LATER)).toEqual({
      linked: 0,
      moved: 0,
      imported: 0,
    })
    expect(await BookQuery.all(reader)).toHaveLength(1)
  })
})

describe('running the nightly job over every reader', () => {
  const other = 'reader-2' as UserId

  test('steps over a reader Amazon refuses and finishes the others', async () => {
    await connect()
    await connect(other)
    // The refused reader is whichever is reached first; both were connected in
    // the same instant, so only the counts are asserted.
    libraryRefusals.push(new Error('device revoked'))
    items = [anItem()]

    expect(await AudibleUseCase.syncEveryReader()).toEqual({ synced: 1, failed: 1, deferred: 0 })
  })

  test('counts a reader who turned the sync off as nobody to sync', async () => {
    await connect()
    await AudibleCommand.setAutoSync(reader, false)

    expect(await AudibleUseCase.syncEveryReader()).toEqual({ synced: 0, failed: 0, deferred: 0 })
    expect(libraryCalls).toHaveLength(0)
  })

  // The budget is what keeps a long run from being killed mid-library. Whoever
  // it cuts off is first in line the next night, which the ordering guarantees.
  test('leaves the readers it cannot reach in time for the next run', async () => {
    await connect()
    await connect(other)

    expect(await AudibleUseCase.syncEveryReader(-1)).toEqual({
      synced: 0,
      failed: 0,
      deferred: 2,
    })
    expect(libraryCalls).toHaveLength(0)
  })
})
