import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { randomBytes } from 'node:crypto'
import type { AudibleItem, LastPosition } from 'audible-api-ts'
import type { AudibleAsin } from '~/domain/audible/types'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore, startFakeRequest } from '~/test/fake-firestore'

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
/** Where the player last stopped, per title, as Amazon would answer it. */
let positions: LastPosition[] = []
const positionCalls: string[][] = []
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
  lastPositions: async (_credentials: unknown, asins: readonly string[]) => {
    positionCalls.push([...asins])
    return {
      positions: positions.filter((position) => asins.includes(position.asin)),
      credentials: {
        accessToken: 'access-3',
        refreshToken: 'Atnr|the-refresh-token',
        adpToken: '{enc:token}',
        devicePrivateKey: 'key',
        serial: 'SERIAL1',
        locale: 'fr',
        expiresAt: new Date('2026-09-19T13:00:00.000Z'),
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
const { ListeningMinutes } = await import('~/domain/book/primitives')
const { SeriesId, SeriesName, VolumeNumber } = await import('~/domain/series/primitives')

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
  positions = []
  libraryCalls.length = 0
  positionCalls.length = 0
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
    startFakeRequest()

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

  // The library is cut into months on the finish, else the start, else the
  // addition. A title bought in 2019 and never opened belongs to 2019, and one
  // half-listened since 2019 has no better start than that.
  test('dates an unread title on the day Audible added it, not on import night', async () => {
    await connect()
    const dateAdded = new Date('2019-06-01T00:00:00.000Z')
    items = [
      anItem({ dateAdded }),
      anItem({
        asin: 'B00X57B4KE',
        title: 'La Peur du sage',
        dateAdded,
        listeningStatus: { percentComplete: 30 },
      }),
    ]

    await AudibleUseCase.importBooks(reader, [asin('B002V1OF70'), asin('B00X57B4KE')])

    // Field by field: Bun's toMatchObject holds any two dates equal.
    const [unread, started] = await BookQuery.all(reader)
    expect(unread?.status).toBe('to-read')
    expect(unread?.addedAt).toEqual(dateAdded)
    expect(started?.status).toBe('reading')
    expect(started?.addedAt).toEqual(dateAdded)
    expect(started?.startedAt).toEqual(dateAdded)
  })

  // The library says 0% of a title the reader is two hours into. Where the
  // player last stopped is the signal, asked for every title in one pass.
  test('catalogues a title the player stopped well into as being read', async () => {
    await connect()
    const dateAdded = new Date('2026-09-14T20:19:22.409Z')
    items = [anItem({ dateAdded, listeningStatus: { percentComplete: 0 } })]
    positions = [
      {
        asin: 'B002V1OF70',
        positionMs: 138 * 60 * 1000,
        lastUpdatedAt: new Date('2026-09-16T20:55:15.357Z'),
      },
    ]

    await AudibleUseCase.importBooks(reader, [asin('B002V1OF70')])

    const [book] = await BookQuery.all(reader)
    expect(book?.status).toBe('reading')
    expect(book?.startedAt).toEqual(dateAdded)
    expect(positionCalls).toEqual([['B002V1OF70']])
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

    // The last rotation of the pass — the positions are asked after the library.
    expect(libraryCalls[1]).toMatchObject({ accessToken: 'access-3' })
    expect(JSON.stringify(fake.data('audible-connections', reader))).not.toContain('access-3')
  })

  // The dashboard is derived data. It must never look fresh over books it does
  // not count, so it is marked stale before the first one lands, and its next
  // read rebuilds it.
  test('leaves the dashboard stale over the imported books', async () => {
    await connect()
    items = [
      anItem({
        listeningStatus: { isFinished: true, finishedAt: new Date('2026-09-01T00:00:00.000Z') },
      }),
    ]

    await AudibleUseCase.importBooks(reader, [asin('B002V1OF70')])

    expect(fake.data('analytics', reader)).toMatchObject({ stale: true })
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
      redated: 0,
      renumbered: 0,
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
    // Catalogued before the finish: added on the wall clock, the book's status
    // stamp would overtake Audible's date the day the test runs past it.
    await BookCommand.add(
      reader,
      {
        title: BookTitle('Le Nom du vent'),
        authors: [AuthorName('Patrick Rothfuss')],
        format: 'audiobook',
      },
      NOW,
    )
    items = [anItem({ listeningStatus: { isFinished: true, finishedAt } })]

    expect(await AudibleUseCase.syncLibrary(reader, LATER)).toEqual({
      linked: 1,
      moved: 1,
      imported: 0,
      redated: 0,
      renumbered: 0,
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
      redated: 0,
      renumbered: 0,
    })
    const [book] = await BookQuery.all(reader)
    expect(book?.status).toBe('to-read')
  })

  // Books imported before the purchase date was kept all sit on import night.
  // The pass moves them back, once: after that the dates agree and nothing moves.
  test('dates a book imported before the purchase date was kept back to the purchase', async () => {
    await connect()
    await AudibleCommand.recordImport(reader, NOW)
    const dateAdded = new Date('2019-06-01T00:00:00.000Z')
    await BookCommand.add(
      reader,
      {
        title: BookTitle('Le Nom du vent'),
        authors: [AuthorName('Patrick Rothfuss')],
        format: 'audiobook',
        status: 'reading',
        audibleAsin: asin('B002V1OF70'),
      },
      NOW,
    )
    items = [anItem({ dateAdded, listeningStatus: { percentComplete: 30 } })]

    expect(await AudibleUseCase.syncLibrary(reader, LATER)).toEqual({
      linked: 0,
      moved: 0,
      imported: 0,
      redated: 1,
      renumbered: 0,
    })
    const [book] = await BookQuery.all(reader)
    expect(book?.addedAt).toEqual(dateAdded)
    expect(book?.startedAt).toEqual(dateAdded)
    expect(book?.statusChangedAt).toEqual(dateAdded)
    expect(book?.updatedAt).toEqual(LATER)

    expect(await AudibleUseCase.syncLibrary(reader, LATER)).toMatchObject({ redated: 0 })
  })

  // Split novels were imported without a rank, and the saga drew a placeholder
  // for the very volume the reader holds. The pass numbers them, once.
  test('numbers the part of a split novel imported without a rank', async () => {
    await connect()
    await AudibleCommand.recordImport(reader, NOW)
    await BookCommand.add(
      reader,
      {
        title: BookTitle('Le Nom du Vent - Seconde partie'),
        authors: [AuthorName('Patrick Rothfuss')],
        format: 'audiobook',
        audibleAsin: asin('B002V1OF70'),
        series: {
          id: SeriesId('chronique-du-tueur-de-roi--patrick-rothfuss'),
          name: SeriesName('Chronique du Tueur de Roi'),
          kind: 'main',
        },
      },
      NOW,
    )
    items = [anItem({ series: { name: 'Chronique du Tueur de Roi', position: 1.2 } })]

    expect(await AudibleUseCase.syncLibrary(reader, LATER)).toMatchObject({ renumbered: 1 })
    const [book] = await BookQuery.all(reader)
    expect(book?.series?.volume).toBe(VolumeNumber(1))
    expect(book?.updatedAt).toEqual(LATER)

    expect(await AudibleUseCase.syncLibrary(reader, LATER)).toMatchObject({ renumbered: 0 })
  })

  // A book the old rule left on the pile, and one the reader started since:
  // both move on the position, dated on the day the player last heard them.
  test('starts a book on the pile once the player has stopped well into it', async () => {
    await connect()
    await AudibleCommand.recordImport(reader, NOW)
    await BookCommand.add(
      reader,
      {
        title: BookTitle('Le Nom du vent'),
        authors: [AuthorName('Patrick Rothfuss')],
        format: 'audiobook',
        audibleAsin: asin('B002V1OF70'),
      },
      NOW,
    )
    const lastHeard = new Date('2026-09-24T20:55:15.357Z')
    items = [anItem({ listeningStatus: { percentComplete: 0 } })]
    positions = [{ asin: 'B002V1OF70', positionMs: 138 * 60 * 1000, lastUpdatedAt: lastHeard }]

    expect(await AudibleUseCase.syncLibrary(reader, LATER)).toMatchObject({ moved: 1 })
    const [book] = await BookQuery.all(reader)
    expect(book?.status).toBe('reading')
    expect(book?.startedAt).toEqual(lastHeard)
  })

  test('follows how far the player got, and finishes a title three minutes from its end', async () => {
    await connect()
    await AudibleCommand.recordImport(reader, NOW)
    await BookCommand.add(
      reader,
      {
        title: BookTitle('Le Nom du vent'),
        authors: [AuthorName('Patrick Rothfuss')],
        format: 'audiobook',
        durationMinutes: ListeningMinutes(600),
        audibleAsin: asin('B002V1OF70'),
        status: 'reading',
      },
      NOW,
    )
    const lastHeard = new Date('2026-09-24T20:55:15.357Z')
    items = [anItem({ durationMinutes: 600, listeningStatus: { percentComplete: 0 } })]
    positions = [{ asin: 'B002V1OF70', positionMs: 598 * 60 * 1000, lastUpdatedAt: lastHeard }]

    await AudibleUseCase.syncLibrary(reader, LATER)

    const [book] = await BookQuery.all(reader)
    expect(book?.listenedMinutes).toBe(ListeningMinutes(598))
    expect(book?.status).toBe('read')
    expect(book?.finishedAt).toEqual(lastHeard)
  })

  // The pass already holds the whole shelf: moving a book must not read it again,
  // or a night that moves forty books pays for them twice.
  test('reads the shelf once, however many books it moves', async () => {
    await connect()
    await AudibleCommand.recordImport(reader, NOW)
    const titles = ['B000000001', 'B000000002', 'B000000003']
    for (const id of titles)
      await BookCommand.add(
        reader,
        {
          title: BookTitle(`Tome ${id}`),
          authors: [AuthorName('Patrick Rothfuss')],
          format: 'audiobook',
          durationMinutes: ListeningMinutes(600),
          audibleAsin: asin(id),
          status: 'reading',
        },
        NOW,
      )
    const lastHeard = new Date('2026-09-24T20:55:15.357Z')
    items = titles.map((id) =>
      anItem({ asin: id, durationMinutes: 600, listeningStatus: { percentComplete: 0 } }),
    )
    positions = titles.map((id) => ({
      asin: id,
      positionMs: 598 * 60 * 1000,
      lastUpdatedAt: lastHeard,
    }))
    startFakeRequest()
    const before = { docs: fake.docReads, queries: fake.queryReads }

    expect(await AudibleUseCase.syncLibrary(reader, LATER)).toMatchObject({ moved: 3 })

    // One scan of the shelf; the one document is the Audible connection.
    expect(fake.queryReads - before.queries).toBe(1)
    expect(fake.docReads - before.docs).toBe(1)
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
      redated: 0,
      renumbered: 0,
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
