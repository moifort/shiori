import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { randomBytes } from 'node:crypto'
import type { AudibleItem } from 'audible-api-ts'
import type { UserId } from '~/domain/shared/types'
import {
  type FakeFirestore,
  fakeDb,
  resetFakeFirestore,
  startFakeRequest,
} from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/object-store', () => ({
  objectStore: () => ({ downloadUrl: async () => 'https://fake.store/cover' }),
}))
const audibleKey = randomBytes(32).toString('base64')
mock.module('~/system/config', () => ({ config: () => ({ audibleKey }) }))

const pushed: string[] = []
mock.module('~/system/apns', () => ({
  Apns: {
    send: async (_device: unknown, message: { body: string }) => {
      pushed.push(message.body)
      return 'sent'
    },
  },
}))

/** Stands in for Gemini: the editions of every work it is asked about in the
 *  language asked, and a count of the calls made, which is what the shared
 *  watches save. */
const calls: string[] = []
let carlDate = '2027-02-19'
mock.module('~/domain/scan/gemini', () => ({
  generate: async ({ step, parts }: { step: string; parts: { text: string }[] }) => {
    calls.push(step)
    // The scan's grounded step, for a book preview.
    if (step === 'enrichment')
      return {
        usage: { promptTokens: 1, outputTokens: 1, thinkingTokens: 0, searches: 1 },
        value: { title: 'Carl 4', authors: ['Matt Dinniman'], synopsis: 'Le tome 4.' },
      }
    const keys = [...(parts[0]?.text ?? '').matchAll(/^- (\S+) :/gm)].map((match) => match[1])
    const answers: Record<string, unknown> = {
      'series--dungeon-crawler-carl--matt-dinniman--fr': {
        translatedTitle: 'Dungeon Crawler Carl',
        editions: [
          { title: 'Dungeon Crawler Carl', volume: 1, format: 'book', date: '2024-05-02' },
          { title: 'Carl 4', volume: 4, format: 'book', date: carlDate },
          { title: 'Carl 4', volume: 4, format: 'audiobook', date: '2027-03' },
        ],
      },
      'series--dungeon-crawler-carl--matt-dinniman--en': {
        editions: [
          { title: 'Carl 2 (en)', volume: 2, format: 'book', date: '2023-01-01' },
          { title: 'Carl 3 (en)', volume: 3, format: 'book', date: '2027-01' },
        ],
      },
      'book--project-hail-mary--andy-weir--fr': {
        translatedTitle: 'Projet Dernière Chance',
        editions: [{ title: 'Projet Dernière Chance', format: 'book', date: '2021-10-06' }],
      },
    }
    return {
      usage: { promptTokens: 1, outputTokens: 1, thinkingTokens: 0, searches: 1 },
      value: { works: keys.map((key) => ({ key, ...(answers[key] ?? { editions: [] }) })) },
    }
  },
}))

const shelved = (item: Partial<AudibleItem>) =>
  ({
    narrators: [],
    durationMinutes: 600,
    categories: [{ root: 'Genres', categories: [{ id: 'sf', name: 'SF' }] }],
    keywords: [],
    relationships: [],
    isAdultProduct: false,
    productImages: {},
    socialMediaImages: {},
    ...item,
  }) as AudibleItem
const credentials = {
  accessToken: 'access',
  refreshToken: 'Atnr|refresh',
  adpToken: '{enc:token}',
  devicePrivateKey: 'key',
  serial: 'SERIAL1',
  locale: 'fr',
  expiresAt: new Date('2027-01-01T00:00:00.000Z'),
}
mock.module('~/domain/audible/infrastructure/audible-api', () => ({
  login: async (marketplace: string) => ({
    loginUrl: `https://www.amazon.${marketplace}/ap/signin`,
    session: { codeVerifier: 'v', serial: 'SERIAL1', marketplace, createdAt: new Date() },
    cookies: [],
  }),
  register: async () => credentials,
  library: async () => ({
    items: [shelved({ asin: 'B0OWNED001', title: 'Project Hail Mary', authors: ['Andy Weir'] })],
    credentials,
  }),
  lastPositions: async () => ({ positions: [], credentials }),
  landingUrlOf: (marketplace: string) => `https://www.amazon.${marketplace}/ap/maplanding`,
}))

const { AudibleCommand } = await import('~/domain/audible/command')
const { BookUseCase } = await import('~/domain/book/use-case')
const { DiscoverUseCase } = await import('~/domain/discover/use-case')
const { DiscoverQuery } = await import('~/domain/discover/query')
const { NotificationCommand } = await import('~/domain/notification/command')
const { DeviceToken } = await import('~/domain/notification/primitives')
const { BookTitle, AuthorName } = await import('~/domain/shared/primitives')
const { seriesKeyOf } = await import('~/domain/series/primitives')

const reader = 'reader' as UserId
const other = 'other' as UserId
const now = new Date('2026-09-24T08:00:00Z')
let fake: FakeFirestore

/** Two volumes of a saga and a novel read in English, and one French book. */
const stock = async (userId: UserId) => {
  for (const volume of [1, 2])
    await BookUseCase.add(userId, {
      title: BookTitle(`Carl ${volume} (en)`),
      authors: [AuthorName('Matt Dinniman')],
      status: 'read',
      language: 'en',
      series: {
        id: seriesKeyOf('Dungeon Crawler Carl', 'Matt Dinniman', 'book'),
        name: 'Dungeon Crawler Carl' as never,
        volume: volume as never,
        kind: 'main',
      },
    })
  await BookUseCase.add(userId, {
    title: BookTitle('Project Hail Mary'),
    authors: [AuthorName('Andy Weir')],
    status: 'read',
    language: 'en',
  })
  await BookUseCase.add(userId, {
    title: BookTitle('Dune'),
    authors: [AuthorName('Frank Herbert')],
    status: 'read',
    language: 'fr',
  })
}

const connectAudible = async (userId: UserId) => {
  await AudibleCommand.startLogin(userId, 'fr', now)
  await AudibleCommand.completeLogin(userId, 'the-code', now)
}

beforeEach(() => {
  fake = resetFakeFirestore()
  calls.length = 0
  pushed.length = 0
  carlDate = '2027-02-19'
})

describe('the Découvrir tab', () => {
  test('lists what is coming of a saga in each language, and a translation out, without recordings for a reader off Audible', async () => {
    await stock(reader)

    await DiscoverUseCase.refresh(reader, 'fr', now)
    const tab = await DiscoverUseCase.discover(reader, 'fr', now)

    expect(tab.preparedAt).toEqual(now)
    expect(
      tab.upcoming.map((t): unknown[] => [
        t.title,
        t.language,
        t.nextDate,
        t.editions.map((e): unknown[] => [e.volume, e.format]),
      ]),
    ).toEqual([
      ['Dungeon Crawler Carl', 'en', '2027-01', [[3, 'book']]],
      [
        'Dungeon Crawler Carl',
        'fr',
        '2027-02-19',
        [
          [1, 'book'],
          [4, 'book'],
        ],
      ],
    ])
    expect(tab.maybe.map((t): unknown[] => [t.title, t.readIn])).toEqual([
      ['Projet Dernière Chance', 'en'],
    ])
  })

  test('draws each saga release as the Series tab draws its row in that language', async () => {
    await stock(reader)

    await DiscoverUseCase.refresh(reader, 'fr', now)
    const [english, french] = (await DiscoverUseCase.discover(reader, 'fr', now)).upcoming

    expect(english.series).toMatchObject({ language: 'en', ownedCount: 2 })
    expect(english.series?.books).toHaveLength(2)
    expect(french.series).toMatchObject({
      name: 'Dungeon Crawler Carl',
      language: 'fr',
      ownedCount: 0,
      state: null,
      books: [],
    })
  })

  // The saga heard is a saga of its own, with its own row: the saga read
  // announces its books only, whatever the web found recorded.
  test('offers a saga read its printed editions, even to a reader connected to Audible', async () => {
    await stock(reader)
    await connectAudible(reader)

    await DiscoverUseCase.refresh(reader, 'fr', now)
    const [, carl] = (await DiscoverUseCase.discover(reader, 'fr', now)).upcoming

    expect(carl.audibleMarketplace).toBe('fr')
    expect(carl.editions.map((e): unknown[] => [e.volume, e.format, e.date])).toEqual([
      [1, 'book', '2024-05-02'],
      [4, 'book', '2027-02-19'],
    ])
  })

  // The watches are shared documents: the second reader of the same books
  // does not pay for the lookup again.
  test('looks a work up once for every reader who read it', async () => {
    await stock(reader)
    await stock(other)

    await DiscoverUseCase.refresh(reader, 'fr', now)
    startFakeRequest()
    await DiscoverUseCase.refresh(other, 'fr', now)

    // One call per work for the first reader — the saga in English and in
    // French, and the novel — and none for the second.
    expect(calls).toEqual(['discover-releases', 'discover-releases', 'discover-releases'])
  })

  test('never proposes again a work the reader is not interested in', async () => {
    await stock(reader)
    await DiscoverUseCase.refresh(reader, 'fr', now)

    await DiscoverUseCase.dismiss(reader, 'series--dungeon-crawler-carl--matt-dinniman--fr')

    expect(
      (await DiscoverUseCase.discover(reader, 'fr', now)).upcoming.map((t) => t.language),
    ).toEqual(['en'])
  })

  test('never searches again a work the reader is not interested in', async () => {
    await stock(reader)
    await DiscoverUseCase.discover(reader, 'fr', now)
    await DiscoverUseCase.dismiss(reader, 'series--dungeon-crawler-carl--matt-dinniman--fr')

    await DiscoverUseCase.refresh(reader, 'fr', now)

    // The saga in English and the novel; not the saga in French.
    expect(calls).toEqual(['discover-releases', 'discover-releases'])
  })

  test('pushes an edition out today once, the alert being on by default', async () => {
    await stock(reader)
    await NotificationCommand.registerDevice(reader, DeviceToken('a'.repeat(64)), 'production')
    carlDate = '2026-09-24'

    await DiscoverUseCase.refresh(reader, 'fr', now)
    await DiscoverUseCase.sendAlertsToEveryReader(now)
    await DiscoverUseCase.sendAlertsToEveryReader(now)

    expect(pushed).toEqual(['« Carl 4 », tome 4, est disponible en français.'])
  })

  test('refreshes on the hour only the readers whose tab is a day old', async () => {
    await stock(reader)
    await stock(other)
    await DiscoverUseCase.discover(reader, 'fr', now)
    await DiscoverUseCase.refresh(other, 'fr', now)

    const run = await DiscoverUseCase.refreshDueReaders(new Date('2026-09-24T12:00:00Z'))

    expect(run).toEqual({ refreshed: 1, failed: 0, deferred: 0 })
    expect((await DiscoverQuery.feed(reader))?.refreshedAt).toBeDefined()
  })

  test('grants a fresh look on demand once a day', async () => {
    await stock(reader)
    await DiscoverUseCase.refreshOnDemand(reader, 'fr', now)
    const before = calls.length

    const again = await DiscoverUseCase.refreshOnDemand(
      reader,
      'fr',
      new Date('2026-09-24T12:00:00Z'),
    )

    expect(calls.length).toBe(before)
    expect(again.canRefresh).toBe(false)
  })

  test('reads the tab with a handful of documents', async () => {
    await stock(reader)
    await DiscoverUseCase.refresh(reader, 'fr', now)
    startFakeRequest()
    const before = { docs: fake.docReads, queries: fake.queryReads }

    await DiscoverUseCase.discover(reader, 'fr', now)

    // The library and the saga opinions; the feed, the Audible connection,
    // the saga's catalogue in one getAll, and one watch per work — the saga in
    // English and in French, and the novel.
    expect(fake.queryReads - before.queries).toBe(2)
    expect(fake.docReads - before.docs).toBe(6)
  })
})

describe('the release watch and the catalogue', () => {
  test('writes the dates it found into the saga’s catalogue, per language', async () => {
    await stock(reader)
    const { SeriesCommand } = await import('~/domain/series/command')
    const { SeriesQuery } = await import('~/domain/series/query')
    const { SeriesName, VolumeNumber } = await import('~/domain/series/primitives')
    const { Year } = await import('~/domain/shared/primitives')
    const id = seriesKeyOf('Dungeon Crawler Carl', 'Matt Dinniman', 'book')
    await SeriesCommand.catalogue({
      id,
      name: SeriesName('Dungeon Crawler Carl'),
      author: AuthorName('Matt Dinniman'),
      catalogedAt: now,
      volumes: [1, 2].map((number) => ({
        number: VolumeNumber(number),
        title: BookTitle(`Carl ${number} (en)`),
        kind: 'main' as const,
        publishedIn: Year(2020),
      })),
    })
    startFakeRequest()

    await DiscoverUseCase.refresh(reader, 'fr', now)
    startFakeRequest()

    const catalogue = await SeriesQuery.byId(id)
    expect(catalogue?.volumes.map((volume): unknown[] => [volume.number, volume.releases])).toEqual(
      [
        [1, { fr: '2024-05-02' }],
        [2, { en: '2023-01-01' }],
        [3, { en: '2027-01' }],
        [4, { fr: '2027-02-19' }],
      ],
    )
  })
})

describe('a book preview', () => {
  const carlFr = 'series--dungeon-crawler-carl--matt-dinniman--fr'

  test('is built whole for an edition a watch found, then kept for every reader', async () => {
    await stock(reader)
    await DiscoverUseCase.refresh(reader, 'fr', now)
    calls.length = 0

    const first = await DiscoverUseCase.preview(carlFr, BookTitle('Carl 4'), 'fr', now)
    startFakeRequest()
    const again = await DiscoverUseCase.preview(carlFr, BookTitle('Carl 4'), 'fr', now)

    expect(first).toMatchObject({
      title: 'Carl 4',
      authors: ['Matt Dinniman'],
      synopsis: 'Le tome 4.',
      language: 'fr',
    })
    expect(again).toEqual(first)
    expect(calls).toEqual(['enrichment'])
  })

  test('is built again once the book it announced is out', async () => {
    await stock(reader)
    await DiscoverUseCase.refresh(reader, 'fr', now)
    calls.length = 0

    await DiscoverUseCase.preview(carlFr, BookTitle('Carl 4'), 'fr', now)
    startFakeRequest()
    await DiscoverUseCase.preview(carlFr, BookTitle('Carl 4'), 'fr', new Date('2027-02-21'))

    expect(calls).toEqual(['enrichment', 'enrichment'])
  })

  test('is never a free scan of a title no watch found', async () => {
    await stock(reader)
    await DiscoverUseCase.refresh(reader, 'fr', now)
    calls.length = 0

    expect(await DiscoverUseCase.preview(carlFr, BookTitle('Anything'), 'fr', now)).toBeNull()
    expect(
      await DiscoverUseCase.preview('book--nope--fr', BookTitle('Carl 4'), 'fr', now),
    ).toBeNull()
    expect(calls).toEqual([])
  })
})
