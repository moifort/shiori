import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { audiobooksJoinTheSagaHeard } = await import(
  '~/system/migration/migrations/008-audiobooks-join-the-saga-heard'
)

const READ = 'bobiverse--dennis-e-taylor'
const HEARD = 'bobiverse--dennis-e-taylor--audio'

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const seriesOf = (bookId: string) =>
  (fake.data('books', bookId)?.series as { id: string } | undefined)?.id

const run = () => audiobooksJoinTheSagaHeard.migrate({ db: fakeDb() })

const volume = (id: string, userId: string, format: string, number: number) =>
  fake.seed('books', id, {
    userId,
    format,
    series: { id: READ, name: 'Bobiverse', volume: number, kind: 'main' },
  })

const opinion = (userId: string, fields: Record<string, unknown> = {}) =>
  fake.seed('series-opinions', `${userId}--${READ}`, {
    userId,
    seriesId: READ,
    rating: 5,
    ...fields,
  })

describe('moving the audiobooks to the saga heard', () => {
  test('moves every audiobook of a saga, and leaves every other format where it is', async () => {
    volume('heard-1', 'r', 'audiobook', 1)
    volume('heard-2', 'r', 'audiobook', 2)
    volume('read-3', 'r', 'book', 3)
    volume('ebook-4', 'r', 'ebook', 4)
    fake.seed('books', 'standalone', { userId: 'r', format: 'audiobook' })

    expect(await run()).toEqual({ ok: true, transformed: 2 })
    expect(fake.data('books', 'heard-1')?.series).toEqual({
      id: HEARD,
      name: 'Bobiverse',
      volume: 1,
      kind: 'main',
    })
    expect(seriesOf('heard-2')).toBe(HEARD)
    expect(seriesOf('read-3')).toBe(READ)
    expect(seriesOf('ebook-4')).toBe(READ)
    expect(fake.data('books', 'standalone')?.series).toBeUndefined()
  })

  // The saga the reader rated was the one they listened to.
  test('moves the opinion of a saga the reader only listened to', async () => {
    volume('heard-1', 'r', 'audiobook', 1)
    opinion('r', { unfollowed: true })

    await run()

    expect(fake.data('series-opinions', `r--${READ}`)).toBeNull()
    expect(fake.data('series-opinions', `r--${HEARD}`)).toEqual({
      userId: 'r',
      seriesId: HEARD,
      rating: 5,
      unfollowed: true,
    })
  })

  test('copies the opinion of a saga the reader both read and listened to', async () => {
    volume('heard-1', 'r', 'audiobook', 1)
    volume('read-2', 'r', 'book', 2)
    opinion('r')

    await run()

    expect(fake.data('series-opinions', `r--${READ}`)?.seriesId).toBe(READ)
    expect(fake.data('series-opinions', `r--${HEARD}`)?.seriesId).toBe(HEARD)
  })

  test("leaves another reader's opinion of a saga they only read alone", async () => {
    volume('heard-1', 'r', 'audiobook', 1)
    volume('read-1', 'other', 'book', 1)
    opinion('other')

    await run()

    expect(fake.data('series-opinions', `other--${READ}`)?.seriesId).toBe(READ)
    expect(fake.data('series-opinions', `other--${HEARD}`)).toBeNull()
  })

  test('changes nothing on a second run', async () => {
    volume('heard-1', 'r', 'audiobook', 1)
    volume('read-2', 'r', 'book', 2)
    opinion('r')
    await run()

    expect(await run()).toEqual({ ok: true, transformed: 0 })
  })

  test('writes past the 500 a single batch accepts', async () => {
    for (let index = 0; index < 650; index++) volume(`heard-${index}`, 'r', 'audiobook', 1)

    expect(await run()).toEqual({ ok: true, transformed: 650 })
  })
})
