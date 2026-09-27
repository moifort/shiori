import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { BookId } from '~/domain/book/types'
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

/** Stands in for Gemini: the edition asked about, as `answers` holds it by
 *  original title, and every title asked about. */
const asked: string[] = []
let answers: Record<string, unknown> = {}
mock.module('~/domain/scan/gemini', () => ({
  generate: async ({ parts }: { parts: { text: string }[] }) => {
    const title = parts[0]?.text.match(/« ([^»]+) »/)?.[1] ?? '?'
    asked.push(`${title} (${parts[0]?.text.includes('livre audio') ? 'audio' : 'livre'})`)
    return {
      usage: { promptTokens: 1, outputTokens: 1, thinkingTokens: 0, searches: 1 },
      value: answers[title] ?? { found: false },
    }
  },
}))

/** Audible confirms one recording, under the ASIN its French store sells it. */
mock.module('~/domain/discovery/infrastructure/audible-catalogue', () => ({
  audibleEditionOf: async () => 'unknown',
  audibleProductOf: async (asin: string) =>
    asin === 'B0DM67WR2V'
      ? { asin: 'B0FRSTORE1', releaseDate: '2026-09-25', coverUrl: 'https://audible/cover.jpg' }
      : 'unknown',
  audibleSeriesOf: async () => 'unknown',
  audibleRecordingOf: async () => 'unknown',
}))
mock.module('~/domain/discovery/infrastructure/amazon-catalogue', () => ({
  amazonEditionOf: async () => ({ releaseDate: '2027-03-12' }),
}))
mock.module('~/domain/scan/published-cover', () => ({
  publishedCoverOf: async () => 'https://covers.example/vent.jpg',
}))

const { BookUseCase } = await import('~/domain/book/use-case')
const { AwaitedEditionUseCase } = await import('~/domain/awaited-edition/use-case')
const { NotificationCommand } = await import('~/domain/notification/command')
const { DeviceToken } = await import('~/domain/notification/primitives')
const { AuthorName, BookTitle } = await import('~/domain/shared/primitives')

const reader = 'reader' as UserId
const other = 'other' as UserId
const now = new Date('2026-09-26T08:00:00Z')
let fake: FakeFirestore

/** Wind and Truth, read in English, by a reader who listens or not. */
const stock = async (userId: UserId, listens = true): Promise<BookId> => {
  fake.seed('analytics', userId, { userId, audiobookCount: listens ? 3 : 0 })
  const book = await BookUseCase.add(userId, {
    title: BookTitle('Wind and Truth'),
    authors: [AuthorName('Brandon Sanderson')],
    status: 'to-read',
    language: 'en',
    format: 'book',
  })
  return book.id
}

const recorded = {
  found: true,
  title: 'Vent et vérité',
  date: '2026-09-20',
  asin: 'B0DM67WR2V',
}

beforeEach(() => {
  fake = resetFakeFirestore()
  startFakeRequest()
  asked.length = 0
  pushed.length = 0
  answers = {}
})

describe('awaiting a book of one’s own', () => {
  test('looks the edition up at once, and answers where it stands', async () => {
    const bookId = await stock(reader)
    answers = {
      'Wind and Truth': {
        found: true,
        title: 'Vent et vérité',
        date: '2027-03',
        isbn13: '9782226488176',
      },
    }

    const view = await AwaitedEditionUseCase.awaitOwnBook(reader, bookId, 'book', 'fr', now)

    expect(asked).toEqual(['Wind and Truth (livre)'])
    expect(view).toMatchObject({
      format: 'book',
      language: 'fr',
      state: 'announced',
      watched: true,
      found: { title: 'Vent et vérité', date: '2027-03-12' },
    })
  })

  test('pays the web once for every reader awaiting the same edition', async () => {
    await AwaitedEditionUseCase.awaitOwnBook(reader, await stock(reader), 'book', 'fr', now)
    await AwaitedEditionUseCase.awaitOwnBook(other, await stock(other), 'book', 'fr', now)

    expect(asked).toEqual(['Wind and Truth (livre)'])
  })

  test('answers the first when the same edition is awaited twice', async () => {
    const bookId = await stock(reader)
    await AwaitedEditionUseCase.awaitOwnBook(reader, bookId, 'book', 'fr', now)
    await AwaitedEditionUseCase.awaitOwnBook(reader, bookId, 'book', 'fr', now)

    expect(fake.snapshot('awaited-editions').size).toBe(1)
  })

  test('refuses a recording to a reader who never listens, and a book in their language', async () => {
    expect(
      await AwaitedEditionUseCase.awaitOwnBook(
        reader,
        await stock(reader, false),
        'audiobook',
        'fr',
        now,
      ),
    ).toBe('not-awaitable')
    expect(
      await AwaitedEditionUseCase.awaitOwnBook(reader, await stock(reader), 'book', 'en', now),
    ).toBe('not-awaitable')
    expect(asked).toEqual([])
  })

  test('keeps a recording only once Audible confirmed it, under its own store’s ASIN', async () => {
    answers = { 'Wind and Truth': recorded }

    const view = await AwaitedEditionUseCase.awaitOwnBook(
      reader,
      await stock(reader),
      'audiobook',
      'fr',
      now,
    )

    expect(view).toMatchObject({
      state: 'available',
      found: { asin: 'B0FRSTORE1', date: '2026-09-25', coverUrl: 'https://audible/cover.jpg' },
    })
  })

  test('never pushes an edition already out when it was awaited', async () => {
    await NotificationCommand.registerDevice(reader, DeviceToken('ab'.repeat(32)), 'production')
    answers = { 'Wind and Truth': recorded }
    await AwaitedEditionUseCase.awaitOwnBook(reader, await stock(reader), 'audiobook', 'fr', now)

    await AwaitedEditionUseCase.sendAlerts(now)

    expect(pushed).toEqual([])
  })

  test('offers the formats the page may await, and the ones awaited', async () => {
    const bookId = await stock(reader)
    await AwaitedEditionUseCase.awaitOwnBook(reader, bookId, 'book', 'fr', now)

    const offer = await AwaitedEditionUseCase.offerForBook(reader, bookId, 'fr', now)

    expect(offer?.formats).toEqual(['book', 'audiobook'])
    expect(offer?.awaited.map((view) => view.format)).toEqual(['book'])
  })
})

describe('the scheduled passes', () => {
  test('look an edition up again once a week, and push it the morning it is out', async () => {
    await NotificationCommand.registerDevice(reader, DeviceToken('ab'.repeat(32)), 'production')
    await AwaitedEditionUseCase.awaitOwnBook(reader, await stock(reader), 'audiobook', 'fr', now)
    asked.length = 0

    await AwaitedEditionUseCase.watchDue(new Date('2026-09-30T08:00:00Z'))
    expect(asked).toEqual([])

    answers = { 'Wind and Truth': { ...recorded } }
    const later = new Date('2026-10-04T08:00:00Z')
    await AwaitedEditionUseCase.watchDue(later)
    expect(asked).toEqual(['Wind and Truth (audio)'])

    await AwaitedEditionUseCase.sendAlerts(later)
    await AwaitedEditionUseCase.sendAlerts(later)
    expect(pushed).toEqual(['« Vent et vérité » de Brandon Sanderson est sorti en livre audio.'])

    // Out: nothing is left to learn.
    await AwaitedEditionUseCase.watchDue(new Date('2026-10-20T08:00:00Z'))
    expect(asked).toEqual(['Wind and Truth (audio)'])
  })
})

describe('the editions awaited', () => {
  test('stop being awaited once the library holds the edition', async () => {
    answers = { 'Wind and Truth': recorded }
    await AwaitedEditionUseCase.awaitOwnBook(reader, await stock(reader), 'audiobook', 'fr', now)
    await BookUseCase.add(reader, {
      title: BookTitle('Vent et vérité'),
      authors: [AuthorName('Brandon Sanderson')],
      status: 'to-read',
      language: 'fr',
      format: 'audiobook',
    })
    startFakeRequest()

    expect(await AwaitedEditionUseCase.awaited(reader, 'audiobook', now)).toEqual([])
    expect(fake.snapshot('awaited-editions').size).toBe(0)
  })

  test('are read in one query and one getAll of their watches', async () => {
    await AwaitedEditionUseCase.awaitOwnBook(reader, await stock(reader), 'book', 'fr', now)
    startFakeRequest()
    const [docReads, queryReads] = [fake.docReads, fake.queryReads]

    const views = await AwaitedEditionUseCase.awaited(reader, 'book', now)

    expect(views.map((view) => view.state)).toEqual(['unannounced'])
    expect(fake.queryReads - queryReads).toBe(1)
    expect(fake.docReads - docReads).toBe(1)
  })

  test('are stopped one by one, the reader’s own only', async () => {
    const view = await AwaitedEditionUseCase.awaitOwnBook(
      reader,
      await stock(reader),
      'book',
      'fr',
      now,
    )
    if (typeof view === 'string') throw new Error(view)

    expect(await AwaitedEditionUseCase.stopAwaiting(other, view.id)).toBe(false)
    expect(await AwaitedEditionUseCase.stopAwaiting(reader, view.id)).toBe(true)
    expect(fake.snapshot('awaited-editions').size).toBe(0)
  })
})
