import { beforeEach, describe, expect, mock, test } from 'bun:test'
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

const pushed: string[] = []
mock.module('~/system/apns', () => ({
  Apns: {
    send: async (_device: unknown, message: { body: string }) => {
      pushed.push(message.body)
      return 'sent'
    },
  },
}))

/** Stands in for Gemini: every volume of the saga asked about, and a count of
 *  the calls made, which is what the shared watches save. */
const calls: string[] = []
mock.module('~/domain/scan/gemini', () => ({
  generate: async ({ parts }: { parts: { text: string }[] }) => {
    const text = parts[0]?.text ?? ''
    calls.push(text.match(/« ([^»]+) »/)?.[1] ?? '?')
    const heard = text.includes('livre audio')
    return {
      usage: { promptTokens: 1, outputTokens: 1, thinkingTokens: 0, searches: 1 },
      value: {
        volumes: heard
          ? [
              { number: 1, title: 'Carl 1', date: '2024-11', asin: 'B0DM67WR2V' },
              { number: 2, title: 'Carl 2', date: '2025-03-01', asin: 'B0FAKEFAKE' },
            ]
          : [
              { number: 1, title: 'Carl 1', date: '2024-05-02', isbn13: '9782226488176' },
              { number: 2, title: 'Carl 2', date: '2025-01-15' },
              { number: 3, title: 'Carl 3', date: '2026-09-26' },
              { number: 4, title: 'Carl 4', date: '2027-02-12' },
            ],
      },
    }
  },
}))

/** Audible knows the first recording and not the second. */
mock.module('~/domain/discovery/infrastructure/audible-catalogue', () => ({
  audibleProductOf: async (asin: string) =>
    asin === 'B0DM67WR2V'
      ? { releaseDate: '2024-11-22', coverUrl: 'https://m.media-amazon.com/carl1.jpg' }
      : 'unknown',
}))
mock.module('~/domain/scan/published-cover', () => ({
  publishedCoverOf: async () => 'https://covers.example/carl1.jpg',
}))

const { BookUseCase } = await import('~/domain/book/use-case')
const { DiscoveryUseCase } = await import('~/domain/discovery/use-case')
const { DiscoveryQuery } = await import('~/domain/discovery/query')
const { NotificationCommand } = await import('~/domain/notification/command')
const { DeviceToken } = await import('~/domain/notification/primitives')
const { SeriesCommand } = await import('~/domain/series/command')
const { SeriesQuery } = await import('~/domain/series/query')
const { SeriesOpinionCommand } = await import('~/domain/series-opinion/command')
const { SeriesName, VolumeNumber, seriesKeyOf } = await import('~/domain/series/primitives')
const { AuthorName, BookTitle, Year } = await import('~/domain/shared/primitives')

const reader = 'reader' as UserId
const other = 'other' as UserId
const now = new Date('2026-09-26T08:00:00Z')
const carl = seriesKeyOf('Dungeon Crawler Carl', 'Matt Dinniman', 'book')
const carlHeard = seriesKeyOf('Dungeon Crawler Carl', 'Matt Dinniman', 'audiobook')
let fake: FakeFirestore

/** An account, and the first volume of Dungeon Crawler Carl read in French. */
const stock = async (userId: UserId, format: 'book' | 'audiobook' = 'book') => {
  fake.seed('users', userId, { userId, firstName: 'Bob' })
  await BookUseCase.add(userId, {
    title: BookTitle('Carl 1'),
    authors: [AuthorName('Matt Dinniman')],
    status: 'read',
    language: 'fr',
    format,
    series: {
      id: format === 'book' ? carl : carlHeard,
      name: SeriesName('Dungeon Crawler Carl'),
      volume: VolumeNumber(1),
      kind: 'main',
    },
  })
}

beforeEach(() => {
  fake = resetFakeFirestore()
  calls.length = 0
  pushed.length = 0
})

describe('the hourly pass', () => {
  test('looks every followed saga up once for every reader who follows it', async () => {
    await stock(reader)
    await stock(other)

    const result = await DiscoveryUseCase.watchDueSagas(now)

    expect(result).toEqual({ synced: 2, watched: 1, failed: 0, deferred: 0 })
    expect(calls).toEqual(['Dungeon Crawler Carl'])
  })

  test('looks a saga up again only once its watch is a week old', async () => {
    await stock(reader)
    await DiscoveryUseCase.watchDueSagas(now)
    calls.length = 0

    await DiscoveryUseCase.watchDueSagas(new Date('2026-09-30T08:00:00Z'))
    expect(calls).toEqual([])
    await DiscoveryUseCase.watchDueSagas(new Date('2026-10-04T08:00:00Z'))
    expect(calls).toEqual(['Dungeon Crawler Carl'])
  })

  test('never looks up a saga the reader set aside', async () => {
    await stock(reader)
    await SeriesOpinionCommand.setFollowed(reader, carl, false, 'fr', ['fr'])

    await DiscoveryUseCase.watchDueSagas(now)

    expect(calls).toEqual([])
  })

  test('writes the dates it found into the saga’s catalogue', async () => {
    await stock(reader)
    await SeriesCommand.catalogue({
      id: carl,
      name: SeriesName('Dungeon Crawler Carl'),
      author: AuthorName('Matt Dinniman'),
      catalogedAt: now,
      volumes: [1, 2].map((number) => ({
        number: VolumeNumber(number),
        title: BookTitle(`Carl ${number}`),
        kind: 'main' as const,
        publishedIn: Year(2024),
      })),
    })

    await DiscoveryUseCase.watchDueSagas(now)
    startFakeRequest()

    const catalogue = await SeriesQuery.byId(carl)
    expect(catalogue?.volumes.map((volume): unknown[] => [volume.number, volume.releases])).toEqual(
      [
        [1, { fr: '2024-05-02' }],
        [2, { fr: '2025-01-15' }],
        [3, { fr: '2026-09-26' }],
        [4, { fr: '2027-02-12' }],
      ],
    )
  })

  test('keeps a recording’s ASIN only once Audible confirms it, with Audible’s date', async () => {
    await stock(reader, 'audiobook')

    await DiscoveryUseCase.watchDueSagas(now)

    const watch = (await DiscoveryQuery.watches([`${carlHeard}--fr`])).get(`${carlHeard}--fr`)
    expect(watch?.volumes).toEqual([
      {
        number: VolumeNumber(1),
        title: BookTitle('Carl 1'),
        date: '2024-11-22' as never,
        asin: 'B0DM67WR2V' as never,
        coverUrl: 'https://m.media-amazon.com/carl1.jpg' as never,
      },
      { number: VolumeNumber(2), title: BookTitle('Carl 2'), date: '2025-03-01' as never },
    ])
  })
})

describe('the Découvrir tab', () => {
  test('offers the volumes out the reader does not hold, and the next one announced', async () => {
    await stock(reader)
    await DiscoveryUseCase.watchDueSagas(now)

    const { sagas, unwatched } = await DiscoveryUseCase.discover(reader, 'fr', 'book', now)
    const [row, ...rest] = sagas

    expect(unwatched).toBe(0)

    expect(rest).toEqual([])
    expect(row.series.name).toBe(SeriesName('Dungeon Crawler Carl'))
    expect(row.available.map((volume): unknown[] => [volume.number, volume.storeUrl])).toEqual([
      [2, 'https://www.amazon.fr/s?k=Carl%202%20Matt%20Dinniman'],
      [3, 'https://www.amazon.fr/s?k=Carl%203%20Matt%20Dinniman'],
    ])
    expect(row.next?.number).toBe(VolumeNumber(4))
  })

  test('shows only the sagas of the format asked', async () => {
    await stock(reader, 'audiobook')
    await DiscoveryUseCase.watchDueSagas(now)

    expect(await DiscoveryUseCase.discover(reader, 'fr', 'book', now)).toEqual({
      sagas: [],
      unwatched: 0,
    })
    const [heard] = (await DiscoveryUseCase.discover(reader, 'fr', 'audiobook', now)).sagas
    expect(heard.available.map((volume) => volume.storeUrl)).toEqual([
      'https://www.audible.fr/search?keywords=Carl%202%20Matt%20Dinniman',
    ])
  })

  test('counts the sagas never looked up, and looks them up on the first look', async () => {
    await stock(reader)
    await stock(reader, 'audiobook')

    expect((await DiscoveryUseCase.discover(reader, 'fr', 'book', now)).unwatched).toBe(1)
    const tab = await DiscoveryUseCase.lookUpUnwatched(reader, 'fr', 'book', now)

    // The saga read only: the saga heard waits for its own tab, or the hour.
    expect(calls).toEqual(['Dungeon Crawler Carl'])
    expect(tab.unwatched).toBe(0)
    expect(tab.sagas.map((row) => row.series.id)).toEqual([carl])
    expect((await DiscoveryUseCase.discover(reader, 'fr', 'audiobook', now)).unwatched).toBe(1)
  })

  test('leaves the rest to the hourly pass once the budget is spent', async () => {
    await stock(reader)

    const tab = await DiscoveryUseCase.lookUpUnwatched(reader, 'fr', 'book', now, 0, 0)

    expect(calls).toEqual([])
    expect(tab.unwatched).toBe(1)
  })

  test('tells the hourly pass at once about a saga followed since', async () => {
    await stock(reader)

    await DiscoveryUseCase.discover(reader, 'fr', 'book', now)

    expect((await DiscoveryQuery.reader(reader))?.sagas.map((saga) => saga.seriesId)).toEqual([
      carl,
    ])
  })

  test('reads the tab with a handful of documents', async () => {
    await stock(reader)
    await DiscoveryUseCase.watchDueSagas(now)
    await DiscoveryUseCase.discover(reader, 'fr', 'book', now)
    startFakeRequest()
    const before = { docs: fake.docReads, queries: fake.queryReads }

    await DiscoveryUseCase.discover(reader, 'fr', 'book', now)

    // The library and the saga opinions; the reader's record, the saga's
    // catalogue, and its watch.
    expect(fake.queryReads - before.queries).toBe(2)
    expect(fake.docReads - before.docs).toBe(3)
  })
})

describe('the saga screen', () => {
  test('shows what the saga has for the reader in the edition they opened', async () => {
    await stock(reader)
    await DiscoveryUseCase.watchDueSagas(now)

    const releases = await DiscoveryUseCase.sagaReleases(reader, carl, 'fr', now)

    expect(releases.available.map((volume) => volume.number)).toEqual([2, 3].map(VolumeNumber))
    expect(releases.next?.date).toBe('2027-02-12' as never)
    expect(await DiscoveryUseCase.sagaReleases(reader, carl, 'en', now)).toEqual({
      watched: false,
      available: [],
    })
  })

  test('looks a saga never looked up up when it is opened, and only then', async () => {
    await stock(reader)
    expect((await DiscoveryUseCase.sagaReleases(reader, carl, 'fr', now)).watched).toBe(false)

    const releases = await DiscoveryUseCase.lookUpSaga(reader, carl, 'fr', now)
    await DiscoveryUseCase.lookUpSaga(reader, carl, 'fr', now)

    expect(releases.watched).toBe(true)
    expect(releases.next?.number).toBe(VolumeNumber(4))
    expect(calls).toEqual(['Dungeon Crawler Carl'])
  })
})

describe('the morning alerts', () => {
  test('push a volume out today to the readers who follow its saga, once', async () => {
    await stock(reader)
    await NotificationCommand.registerDevice(reader, DeviceToken('ab'.repeat(32)), 'production')
    await DiscoveryUseCase.watchDueSagas(now)

    await DiscoveryUseCase.sendAlertsToEveryReader(now)
    await DiscoveryUseCase.sendAlertsToEveryReader(now)

    expect(pushed).toEqual(['« Carl 3 », tome 3 de Dungeon Crawler Carl, est sorti.'])
  })
})
