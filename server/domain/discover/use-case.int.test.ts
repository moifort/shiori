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

/** Stands in for Gemini: the French editions of every work it is asked about,
 *  and a count of the calls made, which is what the shared watches save. */
const calls: string[] = []
let carlDate = '2027-02-19'
mock.module('~/domain/scan/gemini', () => ({
  generate: async ({ step, parts }: { step: string; parts: { text: string }[] }) => {
    calls.push(step)
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

/** What the reader's Audible marketplace lists, per author searched. */
let catalogue: Record<string, Partial<AudibleItem>[]> = {}
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
  catalog: async (_credentials: unknown, options: { author?: string }) => ({
    items: (catalogue[options.author ?? ''] ?? []).map(shelved),
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
        id: seriesKeyOf('Dungeon Crawler Carl', 'Matt Dinniman'),
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
  catalogue = {}
})

describe('the Découvrir tab', () => {
  test('lists what is coming and what is out in French, without recordings for a reader off Audible', async () => {
    await stock(reader)

    await DiscoverUseCase.refresh(reader, 'fr', now)
    const tab = await DiscoverUseCase.discover(reader, 'fr', now)

    expect(tab.preparedAt).toEqual(now)
    expect(
      tab.upcoming.map((t): unknown[] => [
        t.title,
        t.nextDate,
        t.editions.map((e): unknown[] => [e.volume, e.format]),
      ]),
    ).toEqual([
      [
        'Dungeon Crawler Carl',
        '2027-02-19',
        [
          [1, 'book'],
          [4, 'book'],
        ],
      ],
    ])
    expect(tab.available.map((t): unknown[] => [t.title, t.originalTitle])).toEqual([
      ['Projet Dernière Chance', 'Project Hail Mary'],
    ])
  })

  test('offers the recordings of the reader’s Audible store, with its dates', async () => {
    await stock(reader)
    await connectAudible(reader)
    catalogue = {
      'Matt Dinniman': [
        {
          asin: 'B0CARL0004',
          title: 'Carl 4',
          authors: ['Matt Dinniman'],
          language: 'french',
          series: { name: 'Dungeon Crawler Carl', position: 4 },
          releaseDate: new Date('2027-01-15'),
        },
      ],
    }

    await DiscoverUseCase.refresh(reader, 'fr', now)
    const [carl] = (await DiscoverUseCase.discover(reader, 'fr', now)).upcoming

    expect(carl.nextDate as string).toBe('2027-01-15')
    expect(carl.audibleMarketplace).toBe('fr')
    expect(
      carl.editions.map((e): unknown[] => [e.volume, e.format, e.date, e.audibleAsin]),
    ).toEqual([
      [1, 'book', '2024-05-02', undefined],
      [4, 'audiobook', '2027-01-15', 'B0CARL0004'],
      [4, 'book', '2027-02-19', undefined],
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

    // One call per work for the first reader — the saga and the novel — and
    // none for the second.
    expect(calls).toEqual(['discover-translations', 'discover-translations'])
  })

  test('never proposes again a work the reader is not interested in', async () => {
    await stock(reader)
    await DiscoverUseCase.refresh(reader, 'fr', now)

    await DiscoverUseCase.dismiss(reader, 'series--dungeon-crawler-carl--matt-dinniman')

    expect((await DiscoverUseCase.discover(reader, 'fr', now)).upcoming).toEqual([])
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

    // The library; the feed and one watch per work.
    expect(fake.queryReads - before.queries).toBe(1)
    expect(fake.docReads - before.docs).toBe(3)
  })
})
