import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import {
  type FakeFirestore,
  fakeDb,
  inConcurrentFakeRequests,
  resetFakeFirestore,
} from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { BookCommand } = await import('~/domain/book/command')
const { BookQuery } = await import('~/domain/book/query')
const { ListeningMinutes } = await import('~/domain/book/primitives')
const { BookTitle, StarRating } = await import('~/domain/shared/primitives')
const { SagaKey, SeriesName, VolumeNumber } = await import('~/domain/series/primitives')

// The nightly Audible and Kindle passes read a reader's whole shelf once, then
// write book after book, minutes later, from that copy. A reader rating a book
// in between used to lose the rating to the pass's write of the whole record,
// and a book deleted in between came back.

const reader = 'reader-1' as UserId
const NOW = new Date('2026-11-10T02:00:00.000Z')
const LATER = new Date('2026-11-10T02:05:00.000Z')

let fake: FakeFirestore

beforeEach(() => {
  fake = resetFakeFirestore()
})

/** A gate one request opens and another waits on. */
const gate = () => {
  let open = () => {}
  const opened = new Promise<void>((resolve) => {
    open = resolve
  })
  return { open, opened }
}

const recording = async () =>
  (await BookCommand.add(reader, { title: BookTitle('Dune'), format: 'audiobook' }, NOW)).id

const listening = { listenedMinutes: ListeningMinutes(120), listenedAt: LATER }

describe('a book written by a sync pass and its reader at once', () => {
  test("keeps the reader's rating that landed after the pass read the shelf", async () => {
    const id = await recording()
    const shelfRead = gate()
    const rated = gate()

    await inConcurrentFakeRequests([
      // The nightly pass: the shelf first, the book's listening much later.
      async () => {
        await BookQuery.all(reader)
        shelfRead.open()
        await rated.opened
        await BookCommand.recordListening(reader, id, listening, LATER)
      },
      // The reader, rating the book in the meantime.
      async () => {
        await shelfRead.opened
        await BookCommand.rate(reader, id, StarRating(4), LATER)
        rated.open()
      },
    ])

    const stored = fake.data('books', id)
    expect(stored?.rating).toBe(4)
    expect(stored?.status).toBe('read')
    expect(stored?.listenedMinutes).toBe(120)
  })

  test("keeps the pass's listening that landed after the reader's screen read the shelf", async () => {
    const id = await recording()
    const shelfRead = gate()
    const synced = gate()

    await inConcurrentFakeRequests([
      // A mutation document that read the shelf, then rates.
      async () => {
        await BookQuery.all(reader)
        shelfRead.open()
        await synced.opened
        await BookCommand.rate(reader, id, StarRating(4), LATER)
      },
      async () => {
        await shelfRead.opened
        await BookCommand.recordListening(reader, id, listening, LATER)
        synced.open()
      },
    ])

    const stored = fake.data('books', id)
    expect(stored?.rating).toBe(4)
    expect(stored?.listenedMinutes).toBe(120)
  })

  test('never brings back a book the reader deleted after the pass read the shelf', async () => {
    const id = await recording()
    const shelfRead = gate()
    const deleted = gate()

    await inConcurrentFakeRequests([
      async () => {
        await BookQuery.all(reader)
        shelfRead.open()
        await deleted.opened
        await BookCommand.recordListening(reader, id, listening, LATER)
      },
      async () => {
        await shelfRead.opened
        await BookCommand.remove(reader, id)
        deleted.open()
      },
    ])

    expect(fake.data('books', id)).toBeNull()
  })

  test("leaves the pass's own shelf as stored, the reader's rating included", async () => {
    const id = await recording()
    const shelfRead = gate()
    const rated = gate()
    let seen: Awaited<ReturnType<typeof BookQuery.all>> = []

    await inConcurrentFakeRequests([
      async () => {
        await BookQuery.all(reader)
        shelfRead.open()
        await rated.opened
        await BookCommand.recordListening(reader, id, listening, LATER)
        seen = await BookQuery.all(reader)
      },
      async () => {
        await shelfRead.opened
        await BookCommand.rate(reader, id, StarRating(4), LATER)
        rated.open()
      },
    ])

    const book = seen.find((candidate) => candidate.id === id)
    expect(book?.rating).toBe(StarRating(4))
    expect(book?.listenedMinutes).toBe(ListeningMinutes(120))
  })

  test('writes a book twice in one request from what the first write stored', async () => {
    const id = await recording()

    await inConcurrentFakeRequests([
      async () => {
        await BookQuery.all(reader)
        await BookCommand.recordListening(reader, id, listening, LATER)
        await BookCommand.rate(reader, id, StarRating(5), LATER)
      },
    ])

    const stored = fake.data('books', id)
    expect(stored?.rating).toBe(5)
    expect(stored?.listenedMinutes).toBe(120)
  })
})

// A saga renamed by its catalogue writes its new name into every reader's
// volumes, read by a query across readers. A book a query read is written over
// what landed since, as one read by id is.
describe('a saga renamed while its reader rates a volume', () => {
  test("keeps the reader's rating that landed after the rename read the volumes", async () => {
    const { id, series } = await BookCommand.add(
      reader,
      {
        title: BookTitle('Carl 1'),
        series: {
          saga: SagaKey('carl--matt-dinniman'),
          name: SeriesName('Carl'),
          volume: VolumeNumber(1),
          kind: 'main',
        },
      },
      NOW,
    )
    if (!series) throw new Error('no series filed')
    // The rename's query answers late, as one across every reader does: the
    // reader's rating lands between its read and its write.
    fake.answerQueriesAfter(20)

    await inConcurrentFakeRequests<unknown>([
      () => BookCommand.nameSeries(series.id, SeriesName('Dungeon Crawler Carl')),
      () => BookCommand.rate(reader, id, StarRating(4), LATER),
    ])

    const stored = fake.data('books', id)
    expect(stored?.rating).toBe(4)
    expect((stored?.series as { name?: string } | undefined)?.name).toBe('Dungeon Crawler Carl')
  })
})
