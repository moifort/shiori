import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { BookId } from '~/domain/book/types'
import type { UserId } from '~/domain/shared/types'
import { SpendCapReached } from '~/system/gemini/spend-cap'
import {
  type FakeFirestore,
  fakeDb,
  resetFakeFirestore,
  startFakeRequest,
} from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
// The BnF is a network call: a French edition falls through to the grounded step.
mock.module('~/domain/scan/infrastructure/bnf', () => ({ bnfEditionsOf: async () => [] }))
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
/** Set, every call is asked and refused: the Gemini credit is spent. */
let capped = false
mock.module('~/system/gemini', () => ({
  generate: async ({ parts }: { parts: { text: string }[] }) => {
    const title = parts[0]?.text.match(/« ([^»]+) »/)?.[1] ?? '?'
    asked.push(`${title} (${parts[0]?.text.includes('livre audio') ? 'audio' : 'livre'})`)
    if (capped) throw new SpendCapReached('prepaid-credits')
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
mock.module('~/domain/book/infrastructure/published-cover', () => ({
  shelfCoverOf: async () => undefined,
  publishedCoverOf: async () => 'https://covers.example/vent.jpg',
  isbnCoversOf: async () => ({}),
  isbnsInLanguage: () => [],
  otherEditionCoversOf: async () => [],
  isImageAt: async () => true,
  isCoverGone: async () => false,
}))

const { BookUseCase } = await import('~/domain/book/use-case')
const { AwaitedEditionUseCase } = await import('~/domain/awaited-edition/use-case')
const { NotificationCommand } = await import('~/domain/notification/command')
const { DeviceToken } = await import('~/domain/notification/primitives')
const { AuthorName, BookTitle } = await import('~/domain/shared/primitives')
const { releaseShownOf } = await import('~/domain/awaited-edition/business-rules')
const { releaseViewOf } = await import('~/domain/release/business-rules')

const reader = 'reader' as UserId
const other = 'other' as UserId
const now = new Date('2026-09-26T08:00:00Z')
let fake: FakeFirestore

/** Wind and Truth, read in English. */
const stock = async (userId: UserId): Promise<BookId> => {
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
  capped = false
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

  test('refuses a book in the reader’s own language translated', async () => {
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

  test('offers a printed book in the app’s language recorded, whether a store sells it or not', async () => {
    answers = {
      'Les Profondeurs de la Terre': { ...recorded, title: 'Les Profondeurs de la Terre' },
    }
    const book = await BookUseCase.add(reader, {
      title: BookTitle('Les Profondeurs de la Terre'),
      authors: [AuthorName('Robert Silverberg')],
      status: 'to-read',
      language: 'fr',
      format: 'book',
    })

    const offer = await AwaitedEditionUseCase.offerForBook(reader, book.id, 'fr', now)
    const view = await AwaitedEditionUseCase.awaitOwnBook(reader, book.id, 'audiobook', 'fr', now)

    expect(offer?.formats).toEqual(['audiobook'])
    expect(view).toMatchObject({ format: 'audiobook', state: 'available' })
  })
})

describe('the scheduled passes', () => {
  // Every edition after the first would be refused too, and reported as its
  // own failure: the first refusal ends the pass, the rest left for next hour.
  test('stop at the first refusal for want of credit', async () => {
    for (const index of Array.from({ length: 7 }, (_, at) => at))
      fake.seed('awaited-editions', `${reader}--book-${index}--audiobook--fr`, {
        id: `${reader}--book-${index}--audiobook--fr`,
        userId: reader,
        format: 'audiobook',
        language: 'fr',
        source: {
          bookId: `book-${index}`,
          ownerId: reader,
          title: `Book ${index}`,
          authors: ['Brandon Sanderson'],
          language: 'en',
        },
        watchKey: `book-${index}--audiobook--fr`,
        awaitedAt: now,
      })
    capped = true

    const result = await AwaitedEditionUseCase.watchDue(now)

    expect(asked).toHaveLength(5)
    expect(result).toEqual({ watched: 0, failed: 5, deferred: 2, changedReaders: [] })
  })

  test('keep an edition out for the morning a device can hear it', async () => {
    await AwaitedEditionUseCase.awaitOwnBook(reader, await stock(reader), 'audiobook', 'fr', now)
    answers = { 'Wind and Truth': { ...recorded } }
    const later = new Date('2026-10-11T08:00:00Z')
    await AwaitedEditionUseCase.watchDue(later)

    await AwaitedEditionUseCase.sendAlerts(later)
    await NotificationCommand.registerDevice(reader, DeviceToken('ab'.repeat(32)), 'production')
    await AwaitedEditionUseCase.sendAlerts(later)

    expect(pushed).toEqual(['« Vent et vérité » de Brandon Sanderson est sorti en livre audio.'])
  })

  test('look an edition up again every two weeks, and push it the morning it is out', async () => {
    await NotificationCommand.registerDevice(reader, DeviceToken('ab'.repeat(32)), 'production')
    await AwaitedEditionUseCase.awaitOwnBook(reader, await stock(reader), 'audiobook', 'fr', now)
    asked.length = 0

    await AwaitedEditionUseCase.watchDue(new Date('2026-10-04T08:00:00Z'))
    expect(asked).toEqual([])

    answers = { 'Wind and Truth': { ...recorded } }
    const later = new Date('2026-10-11T08:00:00Z')
    await AwaitedEditionUseCase.watchDue(later)
    expect(asked).toEqual(['Wind and Truth (audio)'])

    await AwaitedEditionUseCase.sendAlerts(later)
    await AwaitedEditionUseCase.sendAlerts(later)
    expect(pushed).toEqual(['« Vent et vérité » de Brandon Sanderson est sorti en livre audio.'])

    // Out: nothing is left to learn.
    await AwaitedEditionUseCase.watchDue(new Date('2026-11-01T08:00:00Z'))
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

  test('stay on the day they come out, held already, and go the day after', async () => {
    answers = { 'Wind and Truth': recorded }
    await AwaitedEditionUseCase.awaitOwnBook(reader, await stock(reader), 'audiobook', 'fr', now)
    const [{ found }] = await AwaitedEditionUseCase.awaited(reader, 'audiobook', now)
    const releaseDay = new Date(`${found?.date}T09:00:00Z`)
    await BookUseCase.add(reader, {
      title: BookTitle('Vent et vérité'),
      authors: [AuthorName('Brandon Sanderson')],
      status: 'to-read',
      language: 'fr',
      format: 'audiobook',
    })
    startFakeRequest()

    const onTheDay = await AwaitedEditionUseCase.awaited(reader, 'audiobook', releaseDay)
    const dayAfter = new Date(releaseDay.getTime() + 86_400_000)

    expect(onTheDay.map((view) => view.state)).toEqual(['available'])
    expect(await AwaitedEditionUseCase.awaited(reader, 'audiobook', dayAfter)).toEqual([])
    expect(fake.snapshot('awaited-editions').size).toBe(0)
  })

  test('stay awaited once out, while the library holds only the printed copy', async () => {
    answers = {
      'Les Profondeurs de la Terre': { ...recorded, title: 'Les Profondeurs de la Terre' },
    }
    const book = await BookUseCase.add(reader, {
      title: BookTitle('Les Profondeurs de la Terre'),
      authors: [AuthorName('Robert Silverberg')],
      status: 'to-read',
      language: 'fr',
      format: 'book',
    })
    await AwaitedEditionUseCase.awaitOwnBook(reader, book.id, 'audiobook', 'fr', now)
    await AwaitedEditionUseCase.sendAlerts(new Date('2026-12-01T08:00:00Z'))
    startFakeRequest()

    const views = await AwaitedEditionUseCase.awaited(
      reader,
      'audiobook',
      new Date('2026-12-01T08:00:00Z'),
    )

    expect(views.map((view) => view.state)).toEqual(['available'])
    expect(fake.snapshot('awaited-editions').size).toBe(1)
  })

  test('awaited from a scan, stay awaited until the book is added', async () => {
    answers = { 'Wind and Truth': recorded }
    await AwaitedEditionUseCase.awaitScannedBook(
      reader,
      {
        title: BookTitle('Wind and Truth'),
        authors: [AuthorName('Brandon Sanderson')],
        language: 'en',
        format: 'book',
      },
      'audiobook',
      'fr',
      now,
    )
    startFakeRequest()

    expect((await AwaitedEditionUseCase.awaited(reader, 'audiobook', now)).length).toBe(1)
    expect(fake.snapshot('awaited-editions').size).toBe(1)
  })

  test('are read in one query and one getAll of their releases', async () => {
    await AwaitedEditionUseCase.awaitOwnBook(reader, await stock(reader), 'book', 'fr', now)
    startFakeRequest()
    const [docReads, queryReads] = [fake.docReads, fake.queryReads]

    const views = await AwaitedEditionUseCase.awaited(reader, 'book', now)

    expect(views.map((view) => view.state)).toEqual(['unannounced'])
    expect(fake.queryReads - queryReads).toBe(1)
    expect(fake.docReads - docReads).toBe(1)
  })

  test('draw what their page described, in the list and on the page alike', async () => {
    await AwaitedEditionUseCase.awaitScannedBook(
      reader,
      {
        title: BookTitle('La ragazza nella nebbia'),
        authors: [AuthorName('Donato Carrisi')],
        language: 'it',
        format: 'audiobook',
      },
      'audiobook',
      'fr',
      now,
    )
    // Its page described the original, in its own language, while nobody
    // announced the edition: kept in the release every list reads.
    const key = 'ragazza-nella-nebbia--donato-carrisi--audiobook--fr'
    fake.seed('releases', key, {
      ...fake.snapshot('releases').get(key),
      descriptions: {
        fr: {
          description: {
            book: {
              title: 'La ragazza nella nebbia',
              synopsis: 'Une adolescente disparaît.',
              coverUrl: 'https://covers.example/nebbia.jpg',
            },
            narrators: ['Alberto Angrisano'],
          },
          describedAt: now,
          describedFrom: 'ragazza-nella-nebbia~it',
        },
      },
    })
    startFakeRequest()

    const [view] = await AwaitedEditionUseCase.everyAwaited(reader, now)
    if (!view) throw new Error('no edition awaited')
    const listed = releaseViewOf(
      releaseShownOf(view),
      fake.snapshot('releases').get(key) as never,
      'fr',
      now,
    )
    const opened = await AwaitedEditionUseCase.describe(reader, view.id, 'fr', now)

    expect(view.state).toBe('unannounced')
    expect(listed).toMatchObject({
      describedCoverUrl: 'https://covers.example/nebbia.jpg',
      synopsis: 'Une adolescente disparaît.',
      narrators: ['Alberto Angrisano'],
      described: true,
    })
    // The page opens on the same record, and the model is not asked again.
    expect(opened).toEqual(listed)
    expect(asked).toEqual(['La ragazza nella nebbia (audio)'])
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

// The pass used to read every edition awaited and every watch behind them,
// every hour, to look up a handful a week.
describe("the hourly pass's reads", () => {
  const DAY = 86_400_000
  const HOUR = 3_600_000
  const keyOf = (index: number) => `book-${index}--audiobook--fr`
  const awaitedOf = (index: number, awaitedAt: Date) => {
    const id = `${reader}--book-${index}--audiobook--fr`
    fake.seed('awaited-editions', id, {
      id,
      userId: reader,
      format: 'audiobook',
      language: 'fr',
      source: {
        bookId: `book-${index}`,
        ownerId: reader,
        title: `Book ${index}`,
        authors: ['Brandon Sanderson'],
        language: 'en',
      },
      watchKey: keyOf(index),
      awaitedAt,
    })
    return id
  }
  const watchOf = (index: number, checkedAt: Date) =>
    fake.seed('releases', keyOf(index), {
      key: keyOf(index),
      title: `Book ${index}`,
      author: 'Brandon Sanderson',
      originalLanguage: 'en',
      format: 'audiobook',
      language: 'fr',
      checkedAt,
    })
  const pass = async (at: Date) => {
    startFakeRequest()
    asked.length = 0
    const before = fake.docReads + fake.queriedDocs
    const result = await AwaitedEditionUseCase.watchDue(at)
    return { result, reads: fake.docReads + fake.queriedDocs - before, asked: [...asked].sort() }
  }

  // Forty editions looked up three days ago, one three weeks ago, one never.
  const stocked = () => {
    for (let index = 0; index < 40; index++) {
      awaitedOf(index, new Date(now.getTime() - 30 * DAY))
      watchOf(index, new Date(now.getTime() - 3 * DAY))
    }
    awaitedOf(40, new Date(now.getTime() - 30 * DAY))
    watchOf(40, new Date(now.getTime() - 21 * DAY))
    awaitedOf(41, new Date(now.getTime() - 30 * DAY))
  }

  test('reads only the editions that can be due once a pass has run', async () => {
    stocked()
    const first = await pass(now)
    expect(first.asked).toEqual(['Book 40 (audio)', 'Book 41 (audio)'])
    expect(first.reads).toBeGreaterThanOrEqual(84)

    const next = await pass(new Date(now.getTime() + HOUR))

    expect(next.asked).toEqual([])
    expect(next.result).toEqual({ watched: 0, failed: 0, deferred: 0, changedReaders: [] })
    // The state the last pass left; nothing awaited since, nothing due.
    expect(next.reads).toBeLessThanOrEqual(2)
  })

  test('still looks up an edition awaited since, and every one whose two weeks are up', async () => {
    stocked()
    await pass(now)
    awaitedOf(42, new Date(now.getTime() + 2 * HOUR))

    const awaitedSince = await pass(new Date(now.getTime() + 3 * HOUR))
    expect(awaitedSince.asked).toEqual(['Book 42 (audio)'])

    // Eleven days on, the forty looked up three days before the first pass are
    // due, as a pass reading everything finds them.
    const due = await pass(new Date(now.getTime() + 11 * DAY + HOUR))
    expect(due.asked).toHaveLength(40)
  })

  test('never looks up an edition nobody awaits any more', async () => {
    stocked()
    await pass(now)
    const gone = awaitedOf(43, new Date(now.getTime() + HOUR))
    watchOf(43, new Date(now.getTime() - 20 * DAY))
    await fakeDb().collection('awaited-editions').doc(gone).delete()

    const next = await pass(new Date(now.getTime() + 2 * HOUR))

    expect(next.asked).toEqual([])
  })

  test('reads every edition again once a day', async () => {
    stocked()
    await pass(now)

    const nextDay = await pass(new Date(now.getTime() + DAY + HOUR))

    expect(nextDay.reads).toBeGreaterThanOrEqual(42)
    expect(nextDay.asked).toEqual([])
  })
})
