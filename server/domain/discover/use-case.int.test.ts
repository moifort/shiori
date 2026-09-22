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
mock.module('~/domain/scan/published-cover', () => ({ publishedCoverOf: async () => undefined }))

const pushed: string[] = []
mock.module('~/system/apns', () => ({
  Apns: {
    send: async (_device: unknown, message: { body: string }) => {
      pushed.push(message.body)
      return 'sent'
    },
  },
}))

/** Stands in for Gemini: one answer per step, and a count of the calls made,
 *  which is what the shared documents are there to save. */
const calls: string[] = []
let releaseDate = '2026-10-14'
mock.module('~/domain/scan/gemini', () => ({
  generate: async ({ step, parts }: { step: string; parts: { text: string }[] }) => {
    calls.push(step)
    const usage = { promptTokens: 1, outputTokens: 1, thinkingTokens: 0, searches: 1 }
    if (step === 'discover-personal')
      return {
        usage,
        value: {
          becauseYouLoved: [
            {
              anchor: 'Cradle',
              items: [
                {
                  title: 'Dungeon Crawler Carl',
                  authors: ['Matt Dinniman'],
                  reason: 'La même montée en puissance.',
                },
                { title: 'Dune', authors: ['Frank Herbert'], reason: 'Déjà lu, à écarter.' },
              ],
            },
            { anchor: 'Not a loved book', items: [{ title: 'X', authors: ['Y'], reason: 'r' }] },
          ],
          offTrail: [
            {
              title: 'He Who Fights with Monsters',
              authors: ['Shirtaloon'],
              reason: 'Le LitRPG, cousin de Cradle.',
            },
          ],
        },
      }
    if (step === 'discover-genre')
      return {
        usage,
        value: {
          awards: [
            {
              title: 'The Tainted Cup',
              authors: ['Robert Jackson Bennett'],
              award: 'Hugo 2025',
              reason: 'r',
            },
            { title: 'No Award', authors: ['Nobody'], reason: 'dropped without an award' },
          ],
          acclaimed: [
            {
              title: 'Piranesi',
              authors: ['Susanna Clarke'],
              publicRating: 4.3,
              ratingCount: 400000,
              reason: 'r',
            },
          ],
        },
      }
    const key = /- (series--[^ ]+) :/.exec(parts[0]?.text ?? '')?.[1]
    return {
      usage,
      value: {
        subjects: key
          ? [
              {
                key,
                releases: [
                  {
                    title: 'Cradle 13',
                    authors: ['Will Wight'],
                    volume: 13,
                    date: releaseDate,
                    format: 'book',
                  },
                ],
              },
            ]
          : [],
      },
    }
  },
}))

const { BookUseCase } = await import('~/domain/book/use-case')
const { DiscoverUseCase } = await import('~/domain/discover/use-case')
const { DiscoverQuery } = await import('~/domain/discover/query')
const { NotificationCommand } = await import('~/domain/notification/command')
const { DeviceToken } = await import('~/domain/notification/primitives')
const { BookTitle, AuthorName } = await import('~/domain/shared/primitives')
const { seriesKeyOf } = await import('~/domain/series/primitives')

const reader = 'reader' as UserId
const other = 'other' as UserId
const now = new Date('2026-09-22T08:00:00Z')
let fake: FakeFirestore

const stock = async (userId: UserId) => {
  const cradle = await BookUseCase.add(userId, {
    title: BookTitle('Cradle'),
    authors: [AuthorName('Will Wight')],
    status: 'read',
    genre: 'fantasy',
    series: {
      id: seriesKeyOf('Cradle', 'Will Wight'),
      name: 'Cradle' as never,
      volume: 12 as never,
      kind: 'main',
    },
  })
  await BookUseCase.setFavorite(userId, cradle.id, true)
  await BookUseCase.add(userId, {
    title: BookTitle('Dune'),
    authors: [AuthorName('Frank Herbert')],
    status: 'read',
    genre: 'science-fiction',
  })
}

beforeEach(() => {
  fake = resetFakeFirestore()
  calls.length = 0
  pushed.length = 0
  releaseDate = '2026-10-14'
})

describe('refreshing the Découvrir tab', () => {
  test('stores the shelves, leaving out what the reader owns and loves nobody asked for', async () => {
    await stock(reader)

    await DiscoverUseCase.refresh(reader, 'fr', now)
    const tab = await DiscoverUseCase.discover(reader, 'fr', now)

    expect(tab.preparedAt).toEqual(now)
    expect(
      tab.becauseYouLoved.map((shelf) => [
        shelf.anchor as string,
        shelf.items.map((s) => s.title as string),
      ]),
    ).toEqual([['Cradle', ['Dungeon Crawler Carl']]])
    expect(tab.offTrail.map((s) => s.title as string)).toEqual(['He Who Fights with Monsters'])
    expect(tab.awards.map((s) => s.award)).toEqual(['Hugo 2025'])
    expect(tab.acclaimed[0]).toMatchObject({ title: 'Piranesi', publicRating: 4.3 })
    expect(
      tab.releases.map((r) => [r.title as string, r.kind as string, r.date as string]),
    ).toEqual([['Cradle 13', 'series-volume', '2026-10-14']])
  })

  // The saga's release dates are a shared document: the second reader who
  // follows it does not pay for the lookup again.
  test('looks a saga up once for every reader who follows it', async () => {
    await stock(reader)
    await stock(other)

    await DiscoverUseCase.refresh(reader, 'fr', now)
    startFakeRequest()
    await DiscoverUseCase.refresh(other, 'fr', now)

    // Two genres and one watch list for the first reader; the second, who
    // follows the same saga and authors in the same genres, pays only for
    // their own shelves.
    expect(calls.filter((step) => step === 'discover-genre')).toHaveLength(2)
    expect(calls.filter((step) => step === 'discover-releases')).toHaveLength(1)
    expect(calls.filter((step) => step === 'discover-personal')).toHaveLength(2)
  })

  test('pushes a release out today, once, to a reader who switched the alert on', async () => {
    await stock(reader)
    await NotificationCommand.registerDevice(reader, DeviceToken('a'.repeat(64)), 'production')
    await NotificationCommand.setAlert(reader, 'series-volume', true)
    releaseDate = '2026-09-22'

    await DiscoverUseCase.refresh(reader, 'fr', now)
    await DiscoverUseCase.sendAlertsToEveryReader(now)

    expect(pushed).toEqual(["Cradle 13, tome 13 de Cradle, sort aujourd'hui."])
  })

  test('refreshes on the hour only the readers whose tab is a week old', async () => {
    await stock(reader)
    await stock(other)
    await DiscoverUseCase.discover(reader, 'fr', now)
    await DiscoverUseCase.refresh(other, 'fr', now)
    calls.length = 0

    const run = await DiscoverUseCase.refreshDueReaders(new Date('2026-09-23T08:00:00Z'))

    expect(run).toEqual({ refreshed: 1, failed: 0, deferred: 0 })
    expect((await DiscoverQuery.feed(reader))?.refreshedAt).toBeDefined()
  })

  test('grants a fresh set on demand once a day', async () => {
    await stock(reader)
    await DiscoverUseCase.refreshOnDemand(reader, 'fr', now)
    const before = calls.length

    const again = await DiscoverUseCase.refreshOnDemand(
      reader,
      'fr',
      new Date('2026-09-22T12:00:00Z'),
    )

    expect(calls.length).toBe(before)
    expect(again.canRefresh).toBe(false)
  })
})

describe('acting on a suggestion', () => {
  test('puts it on the pile from what the tab stored, and never proposes it again', async () => {
    await stock(reader)
    await DiscoverUseCase.refresh(reader, 'fr', now)

    const book = await DiscoverUseCase.addSuggestion(reader, 'piranesi--susanna-clarke', 'to-read')
    const tab = await DiscoverUseCase.discover(reader, 'fr', now)

    expect(book).toMatchObject({ title: 'Piranesi', status: 'to-read' })
    expect(tab.acclaimed).toEqual([])
    expect(await DiscoverUseCase.addSuggestion(reader, 'piranesi--susanna-clarke', 'to-read')).toBe(
      'already-owned',
    )
  })

  test('dismisses it for good', async () => {
    await stock(reader)
    await DiscoverUseCase.refresh(reader, 'fr', now)

    await DiscoverUseCase.dismiss(reader, 'he-who-fights-with-monsters--shirtaloon')

    expect((await DiscoverUseCase.discover(reader, 'fr', now)).offTrail).toEqual([])
  })

  test('reads the tab with a handful of documents, never the friends libraries', async () => {
    await stock(reader)
    await DiscoverUseCase.refresh(reader, 'fr', now)
    startFakeRequest()
    const before = { docs: fake.docReads, queries: fake.queryReads }

    await DiscoverUseCase.discover(reader, 'fr', now)

    // The feed, the genre lists; the library and the friendships.
    expect(fake.queryReads - before.queries).toBe(2)
    expect(fake.docReads - before.docs).toBe(3)
  })
})
