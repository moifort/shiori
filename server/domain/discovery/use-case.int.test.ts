import { beforeEach, describe, expect, mock, spyOn, test } from 'bun:test'
import * as Sentry from '@sentry/node'
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
 *  the calls made, which is what the shared watches save. An author asked
 *  about answers a book of their own, the first volume of a new saga, the next
 *  volume of the saga the reader follows and a book the reader holds. */
const calls: string[] = []
const authorCalls: string[] = []
mock.module('~/domain/scan/gemini', () => ({
  generate: async ({ parts }: { parts: { text: string }[] }) => {
    const text = parts[0]?.text ?? ''
    const heard = text.includes('livre audio')
    const author = text.match(/suit l'auteur (.+?) en /)?.[1]
    if (author) {
      authorCalls.push(`${author} (${heard ? 'audio' : 'livre'})`)
      return {
        usage: { promptTokens: 1, outputTokens: 1, thinkingTokens: 0, searches: 1 },
        value: {
          works: [
            { title: 'Kaiju Battlefield Surgeon', date: '2026-11-03' },
            {
              title: 'La Tour 1',
              date: '2026-09-24',
              isbn13: '9782226488213',
              series: 'La Tour',
              volume: 1,
            },
            { title: 'Carl 8', date: '2026-12-01', series: 'Dungeon Crawler Carl', volume: 8 },
            { title: 'Carl 1', date: '2024-05-02' },
          ],
        },
      }
    }
    calls.push(text.match(/« ([^»]+) »/)?.[1] ?? '?')
    return {
      usage: { promptTokens: 1, outputTokens: 1, thinkingTokens: 0, searches: 1 },
      value: {
        volumes: heard
          ? [
              { number: 1, title: 'Carl 1', date: '2024-11', asin: 'B0DM67WR2V' },
              { number: 2, title: 'Carl 2', date: '2025-03-01', asin: 'B0FAKEFAKE' },
              { number: 3, title: 'Carl 3', date: '2027-05-01', asin: 'B0USSTORE3' },
            ]
          : [
              { number: 1, title: 'Carl 1', date: '2024-05-02', isbn13: '9782226488176' },
              { number: 2, title: 'Carl 2', date: '2025-01-15', isbn13: '9782226488206' },
              { number: 3, title: 'Carl 3', date: '2026-09-26', isbn13: '9782226488190' },
              { number: 4, title: 'Carl 4', date: '2027-02-12' },
            ],
      },
    }
  },
}))

/** Audible knows the first recording and not the second, sells the third
 *  under another ASIN than the one named, and lists the series only when a
 *  test sets `audibleSeries`. */
let audibleSeries: unknown[] | 'unknown' = 'unknown'
const seriesAsked: string[] = []
mock.module('~/domain/discovery/infrastructure/audible-catalogue', () => ({
  audibleEditionOf: async () => 'unknown',
  audibleProductOf: async (asin: string) =>
    asin === 'B0DM67WR2V'
      ? { asin, releaseDate: '2024-11-22', coverUrl: 'https://m.media-amazon.com/carl1.jpg' }
      : asin === 'B0USSTORE3'
        ? { asin: 'B0FRSTORE3' }
        : 'unknown',
  audibleSeriesOf: async (asin: string) => {
    seriesAsked.push(asin)
    return audibleSeries
  },
  audibleRecordingOf: async () => 'unknown',
}))
/** Amazon dates the third French volume a day before the web did, and sells no
 *  book under the ISBN the web gave the second. */
mock.module('~/domain/discovery/infrastructure/amazon-catalogue', () => ({
  amazonEditionOf: async (isbn13: string) =>
    isbn13 === '9782226488190'
      ? { releaseDate: '2026-09-25' }
      : isbn13 === '9782226488206'
        ? 'unknown'
        : 'unreachable',
}))
mock.module('~/domain/scan/published-cover', () => ({
  publishedCoverOf: async () => 'https://covers.example/carl1.jpg',
  isCoverGone: async () => false,
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
const { authorKeyOf } = await import('~/domain/author/primitives')

const reader = 'reader' as UserId
const other = 'other' as UserId
const now = new Date('2026-09-26T08:00:00Z')
const carl = seriesKeyOf('Dungeon Crawler Carl', 'Matt Dinniman', 'book')
const carlHeard = seriesKeyOf('Dungeon Crawler Carl', 'Matt Dinniman', 'audiobook')
let fake: FakeFirestore

/** An account, and the first volume of Dungeon Crawler Carl read in French. */
const stock = async (
  userId: UserId,
  format: 'book' | 'audiobook' = 'book',
  status: 'read' | 'dropped' = 'read',
) => {
  fake.seed('users', userId, { userId, firstName: 'Bob' })
  await BookUseCase.add(userId, {
    title: BookTitle('Carl 1'),
    authors: [AuthorName('Matt Dinniman')],
    status,
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

/** The reader awaits a book of Matt Dinniman's in French, in one format: found
 *  as `found` says, or not found yet. */
const awaits = (
  format: 'book' | 'audiobook',
  original: string,
  found?: { title: string; date?: string; asin?: string },
) => {
  const watchKey = `${original}--${format}--fr`
  fake.seed('awaited-editions', `${reader}--${watchKey}`, {
    id: `${reader}--${watchKey}`,
    userId: reader,
    format,
    language: 'fr',
    source: {
      bookId: `book-${original}`,
      ownerId: reader,
      title: original,
      authors: ['Matt Dinniman'],
      language: 'en',
    },
    watchKey,
    awaitedAt: new Date('2026-09-01T08:00:00Z'),
  })
  if (found)
    fake.seed('edition-watches', watchKey, {
      key: watchKey,
      title: original,
      author: 'Matt Dinniman',
      originalLanguage: 'en',
      format,
      language: 'fr',
      checkedAt: now,
      found,
    })
}

beforeEach(() => {
  fake = resetFakeFirestore()
  calls.length = 0
  authorCalls.length = 0
  pushed.length = 0
  seriesAsked.length = 0
  audibleSeries = 'unknown'
})

describe('the hourly pass', () => {
  test('looks every followed saga up once for every reader who follows it', async () => {
    await stock(reader)
    await stock(other)

    const result = await DiscoveryUseCase.watchDueSagas(now)

    // The saga, and its author.
    expect(result).toEqual({ synced: 2, watched: 2, failed: 0, deferred: 0 })
    expect(calls).toEqual(['Dungeon Crawler Carl'])
    expect(authorCalls).toEqual(['Matt Dinniman (livre)'])
  })

  test('looks a saga up again only once its watch is two weeks old', async () => {
    await stock(reader)
    await DiscoveryUseCase.watchDueSagas(now)
    calls.length = 0

    await DiscoveryUseCase.watchDueSagas(new Date('2026-10-04T08:00:00Z'))
    expect(calls).toEqual([])
    await DiscoveryUseCase.watchDueSagas(new Date('2026-10-11T08:00:00Z'))
    expect(calls).toEqual(['Dungeon Crawler Carl'])
  })

  // The web stops at volume 4: a fifth the reader adds is worth one look the
  // next day, not two weeks later — and no more than one while the web still
  // does not know it.
  test('looks a saga up again once a reader holds a volume its last look did not find', async () => {
    await stock(reader)
    await DiscoveryUseCase.watchDueSagas(now)
    await BookUseCase.add(reader, {
      title: BookTitle('Carl 5'),
      authors: [AuthorName('Matt Dinniman')],
      status: 'read',
      language: 'fr',
      format: 'book',
      addedAt: new Date('2026-09-26T12:00:00Z'),
      series: {
        id: carl,
        name: SeriesName('Dungeon Crawler Carl'),
        volume: VolumeNumber(5),
        kind: 'main',
      },
    })
    calls.length = 0

    await DiscoveryUseCase.watchDueSagas(new Date('2026-09-27T09:00:00Z'))
    expect(calls).toEqual(['Dungeon Crawler Carl'])
    await DiscoveryUseCase.watchDueSagas(new Date('2026-09-28T10:00:00Z'))
    expect(calls).toEqual(['Dungeon Crawler Carl'])
  })

  // An account deleted while a pass was reading it leaves its reader behind:
  // its sagas would be looked up every week for nobody.
  test('forgets a reader whose account is gone, and their sagas with them', async () => {
    fake.seed('discovery-readers', 'gone', {
      userId: 'gone',
      language: 'fr',
      sagas: [{ seriesId: carl, language: 'fr', name: 'Dungeon Crawler Carl' }],
      syncedAt: now,
      notified: [],
    })

    const result = await DiscoveryUseCase.watchDueSagas(now)

    expect(result.watched).toBe(0)
    expect(calls).toEqual([])
    expect(fake.data('discovery-readers', 'gone')).toBeNull()
  })

  test('never looks up a saga the reader set aside', async () => {
    await stock(reader)
    await SeriesOpinionCommand.setFollowed(reader, carl, false, 'fr', ['fr'])

    await DiscoveryUseCase.watchDueSagas(now)

    expect(calls).toEqual([])
  })

  // A volume given up on says the saga lost the reader: its next ones are not
  // worth a look.
  test('never looks up a saga the reader gave up a volume of', async () => {
    await stock(reader, 'book', 'dropped')

    await DiscoveryUseCase.watchDueSagas(now)

    expect(calls).toEqual([])
  })

  test('writes the dates it found into the saga’s catalogue, Amazon’s over the web’s', async () => {
    await stock(reader)
    await SeriesCommand.catalogue({
      language: 'fr',
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

    const catalogue = await SeriesQuery.byId({ id: carl, language: 'fr' })
    expect(catalogue?.volumes.map((volume): unknown[] => [volume.number, volume.releases])).toEqual(
      [
        [1, { fr: '2024-05-02' }],
        [2, { fr: '2025-01-15' }],
        [3, { fr: '2026-09-25' }],
        [4, { fr: '2027-02-12' }],
      ],
    )
  })

  test('keeps a recording’s ASIN only once Audible confirms it, with Audible’s date and ASIN', async () => {
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
      {
        number: VolumeNumber(3),
        title: BookTitle('Carl 3'),
        date: '2027-05-01' as never,
        asin: 'B0FRSTORE3' as never,
      },
    ])
  })

  // The web search names identifiers no store sells — a Kindle ASIN, an ISBN
  // that never existed — every run: checking them is the point, not a failure.
  test('drops an ISBN or an ASIN no store knows without reporting it', async () => {
    await stock(reader)
    await stock(reader, 'audiobook')
    const reports = spyOn(Sentry, 'captureMessage')

    try {
      await DiscoveryUseCase.watchDueSagas(now)

      const printed = (await DiscoveryQuery.watches([`${carl}--fr`])).get(`${carl}--fr`)
      expect(printed?.volumes.find((volume) => volume.number === 2)?.isbn13).toBeUndefined()
      expect(reports).not.toHaveBeenCalled()
    } finally {
      reports.mockRestore()
    }
  })
})

describe('a saga heard', () => {
  const listed = [
    { number: 1, title: 'Carl 1', asin: 'B0DM67WR2V', date: '2024-11-22' },
    { number: 2, title: 'Carl 2', asin: 'B0CARLTWO2', date: '2026-10-08' },
  ]

  test('takes Audible’s own listing of the series over the web’s dates', async () => {
    audibleSeries = listed
    await stock(reader, 'audiobook')

    await DiscoveryUseCase.watchDueSagas(now)

    const watch = (await DiscoveryQuery.watches([`${carlHeard}--fr`])).get(`${carlHeard}--fr`)
    // Volume 2 is on preorder on Audible, whatever the web said; volume 3 is
    // only announced, and kept as such.
    expect(watch?.volumes.map((volume): unknown[] => [volume.number, volume.date])).toEqual([
      [1, '2024-11-22'],
      [2, '2026-10-08'],
      [3, '2027-05-01'],
    ])
    expect(seriesAsked).toEqual(['B0DM67WR2V'])
  })

  test('asks Audible alone once a recording of the series is known', async () => {
    audibleSeries = listed
    await stock(reader, 'audiobook')
    await DiscoveryUseCase.watchDueSagas(now)
    calls.length = 0

    await DiscoveryUseCase.watchDueSagas(new Date('2026-10-11T08:00:00Z'))

    expect(calls).toEqual([])
    expect(seriesAsked).toEqual(['B0DM67WR2V', 'B0DM67WR2V'])
  })
})

describe('the Découvrir tab', () => {
  test('offers the next volume announced, and names the ones out', async () => {
    await stock(reader)
    await DiscoveryUseCase.watchDueSagas(now)

    const { sagas, unwatched } = await DiscoveryUseCase.discover(reader, 'fr', 'book', now)
    const [row, ...rest] = sagas

    expect(unwatched).toBe(0)

    expect(rest).toEqual([])
    expect(row.series.name).toBe(SeriesName('Dungeon Crawler Carl'))
    expect(row.next?.number).toBe(VolumeNumber(4))
    expect(row.missing).toEqual([2, 3].map(VolumeNumber))
    // Volume 3 came out yesterday, on Amazon under its ISBN; volume 2 has none.
    expect(row.recent.map((volume) => volume.number)).toEqual([VolumeNumber(3)])
  })

  test('moves a volume announced among the new releases on its day, for two weeks', async () => {
    await stock(reader)
    await DiscoveryUseCase.watchDueSagas(now)
    const tabOn = async (day: string) =>
      (await DiscoveryUseCase.discover(reader, 'fr', 'book', new Date(day))).sagas[0]

    const before = await tabOn('2026-09-24T08:00:00Z')
    expect(before.next?.number).toBe(VolumeNumber(3))
    expect(before.recent).toEqual([])
    expect((await tabOn('2026-10-01T08:00:00Z')).recent.map(({ number }) => number)).toEqual([
      VolumeNumber(3),
    ])
    // Out on September 25th as Amazon dates it: shown through October 8th.
    expect((await tabOn('2026-10-08T08:00:00Z')).recent.map(({ number }) => number)).toEqual([
      VolumeNumber(3),
    ])
    expect((await tabOn('2026-10-09T08:00:00Z')).recent).toEqual([])
    expect(calls).toEqual(['Dungeon Crawler Carl'])
  })

  test('shows only the sagas of the format asked', async () => {
    await stock(reader, 'audiobook')
    await DiscoveryUseCase.watchDueSagas(now)

    // No saga read at all: the app opens on the sagas heard instead.
    expect(await DiscoveryUseCase.discover(reader, 'fr', 'book', now)).toEqual({
      sagas: [],
      authors: [],
      unwatched: 0,
      followed: 0,
    })
    const heardTab = await DiscoveryUseCase.discover(reader, 'fr', 'audiobook', now)
    // The saga heard, and its author heard.
    expect(heardTab.followed).toBe(2)
    const [heard] = heardTab.sagas
    expect(heard.series.id).toBe(carlHeard)
    expect(heard.next?.number).toBe(VolumeNumber(3))
  })

  test('counts the sagas never looked up, and looks them up on the first look', async () => {
    await stock(reader)
    await stock(reader, 'audiobook')

    // The saga and its author, in each format.
    expect((await DiscoveryUseCase.discover(reader, 'fr', 'book', now)).unwatched).toBe(2)
    const tab = await DiscoveryUseCase.lookUpUnwatched(reader, 'fr', 'book', now)

    // The saga read only: the saga heard waits for its own tab, or the hour.
    expect(calls).toEqual(['Dungeon Crawler Carl'])
    expect(authorCalls).toEqual(['Matt Dinniman (livre)'])
    expect(tab.unwatched).toBe(0)
    expect(tab.sagas.map((row) => row.series.id)).toEqual([carl])
    expect((await DiscoveryUseCase.discover(reader, 'fr', 'audiobook', now)).unwatched).toBe(2)
  })

  test('leaves the rest to the hourly pass once the budget is spent', async () => {
    await stock(reader)

    const tab = await DiscoveryUseCase.lookUpUnwatched(reader, 'fr', 'book', now, 0, 0)

    expect(calls).toEqual([])
    expect(tab.unwatched).toBe(2)
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

    // The library, the saga opinions and the editions awaited; the reader's
    // record, the saga's catalogue, its watch, the author's watch and their
    // catalogue for the portrait.
    expect(fake.queryReads - before.queries).toBe(3)
    expect(fake.docReads - before.docs).toBe(5)
  })
})

describe('the Authors shelf', () => {
  test('offers an author’s own book announced and the new saga just out, not the followed saga', async () => {
    await stock(reader)
    await DiscoveryUseCase.watchDueSagas(now)

    const { authors } = await DiscoveryUseCase.discover(reader, 'fr', 'book', now)
    const [row, ...rest] = authors

    expect(rest).toEqual([])
    expect(row.author.name).toBe(AuthorName('Matt Dinniman'))
    expect(row.author.books.map((book) => book.title)).toEqual([BookTitle('Carl 1')])
    expect(row.next?.title).toBe(BookTitle('Kaiju Battlefield Surgeon'))
    expect(row.recent.map((work) => work.title)).toEqual([BookTitle('La Tour 1')])
    // The followed saga's volumes, on the Books shelf, are the author's news too.
    expect(row.sagas.map((saga) => saga.series.id)).toEqual([carl])
  })

  test('adds the editions awaited announced or out to the author’s row and page, not the ones not found', async () => {
    await stock(reader)
    await DiscoveryUseCase.watchDueSagas(now)
    awaits('book', 'The Butcher’s Masquerade', {
      title: 'La Mascarade du boucher',
      date: '2026-11-20',
    })
    awaits('book', 'The Gate of the Feral Gods', {
      title: 'La Porte des dieux',
      date: '2026-09-02',
    })
    awaits('book', 'The Eye of the Bedlam Bride')

    const [row] = (await DiscoveryUseCase.discover(reader, 'fr', 'book', now)).authors
    const page = await DiscoveryUseCase.authorReleases(
      reader,
      authorKeyOf('Matt Dinniman'),
      'book',
      now,
    )

    const shown = [BookTitle('La Porte des dieux'), BookTitle('La Mascarade du boucher')]
    expect(row.awaited.map((view) => view.found?.title)).toEqual(shown)
    expect(row.awaited.map((view) => view.state)).toEqual(['available', 'announced'])
    expect(row.next?.title).toBe(BookTitle('Kaiju Battlefield Surgeon'))
    expect(page.awaited.map((view) => view.found?.title)).toEqual(shown)
  })

  test('draws a work the web found once when the reader awaits it', async () => {
    await stock(reader)
    await DiscoveryUseCase.watchDueSagas(now)
    awaits('book', 'Kaiju: Battlefield Surgeon', {
      title: 'Kaiju Battlefield Surgeon',
      date: '2026-11-03',
    })

    const [row] = (await DiscoveryUseCase.discover(reader, 'fr', 'book', now)).authors

    expect(row.next).toBeUndefined()
    expect(row.awaited.map((view) => view.found?.title)).toEqual([
      BookTitle('Kaiju Battlefield Surgeon'),
    ])
  })

  test('shelves an author among the recordings for a recording awaited, though only read', async () => {
    await stock(reader)
    await DiscoveryUseCase.watchDueSagas(now)
    awaits('audiobook', 'The Butcher’s Masquerade', {
      title: 'La Mascarade du boucher',
      date: '2026-09-02',
      asin: 'B0MASQUE01',
    })

    const [row, ...rest] = (await DiscoveryUseCase.discover(reader, 'fr', 'audiobook', now)).authors

    expect(rest).toEqual([])
    expect(row.author.name).toBe(AuthorName('Matt Dinniman'))
    expect(row.recent).toEqual([])
    expect(row.awaited.map((view) => view.state)).toEqual(['available'])
  })

  test('watches an author only in the formats the reader holds them in', async () => {
    await stock(reader, 'audiobook')

    await DiscoveryUseCase.watchDueSagas(now)

    expect(authorCalls).toEqual(['Matt Dinniman (audio)'])
    expect((await DiscoveryUseCase.discover(reader, 'fr', 'book', now)).authors).toEqual([])
  })

  test('never looks up an author whose every book the reader gave up on', async () => {
    await stock(reader, 'book', 'dropped')

    await DiscoveryUseCase.watchDueSagas(now)

    expect(authorCalls).toEqual([])
  })

  test('looks an author up once a month for every reader who holds them', async () => {
    await stock(reader)
    await stock(other)
    await DiscoveryUseCase.watchDueSagas(now)
    await DiscoveryUseCase.watchDueSagas(new Date('2026-10-20T08:00:00Z'))

    expect(authorCalls).toEqual(['Matt Dinniman (livre)'])
    await DiscoveryUseCase.watchDueSagas(new Date('2026-10-27T08:00:00Z'))
    expect(authorCalls).toEqual(['Matt Dinniman (livre)', 'Matt Dinniman (livre)'])
  })
})

describe('the saga screen', () => {
  test('shows what the saga has for the reader in the edition they opened', async () => {
    await stock(reader)
    await DiscoveryUseCase.watchDueSagas(now)

    const releases = await DiscoveryUseCase.sagaReleases(reader, carl, 'fr', now)

    expect(releases).toEqual({
      watched: true,
      next: { number: VolumeNumber(4), title: BookTitle('Carl 4'), date: '2027-02-12' as never },
    })
    expect(await DiscoveryUseCase.sagaReleases(reader, carl, 'en', now)).toEqual({
      watched: false,
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

  test('never push a volume due while the reader had the alert off', async () => {
    await stock(reader)
    await NotificationCommand.registerDevice(reader, DeviceToken('ab'.repeat(32)), 'production')
    await NotificationCommand.setAlert(reader, 'translation', false)
    await DiscoveryUseCase.watchDueSagas(now)

    await DiscoveryUseCase.sendAlertsToEveryReader(now)
    await NotificationCommand.setAlert(reader, 'translation', true)
    await DiscoveryUseCase.sendAlertsToEveryReader(now)

    expect(pushed).toEqual([])
  })

  test('keep a volume for the morning a device can hear it', async () => {
    await stock(reader)
    await DiscoveryUseCase.watchDueSagas(now)

    await DiscoveryUseCase.sendAlertsToEveryReader(now)
    await NotificationCommand.registerDevice(reader, DeviceToken('ab'.repeat(32)), 'production')
    await DiscoveryUseCase.sendAlertsToEveryReader(now)

    expect(pushed).toEqual(['« Carl 3 », tome 3 de Dungeon Crawler Carl, est sorti.'])
  })
})

describe('the Sunday digest', () => {
  test('names the volumes newly announced in one notification, each once', async () => {
    await stock(reader)
    await NotificationCommand.registerDevice(reader, DeviceToken('ab'.repeat(32)), 'production')
    await DiscoveryUseCase.watchDueSagas(now)

    await DiscoveryUseCase.sendDigestToEveryReader(now)
    await DiscoveryUseCase.sendDigestToEveryReader(now)

    expect(pushed).toEqual(['Dungeon Crawler Carl, tome 4, le 12 février 2027'])
  })

  test('keeps a volume for the Sunday a device can hear it', async () => {
    await stock(reader)
    await DiscoveryUseCase.watchDueSagas(now)

    await DiscoveryUseCase.sendDigestToEveryReader(now)
    await NotificationCommand.registerDevice(reader, DeviceToken('ab'.repeat(32)), 'production')
    await DiscoveryUseCase.sendDigestToEveryReader(now)

    expect(pushed).toEqual(['Dungeon Crawler Carl, tome 4, le 12 février 2027'])
  })
})
