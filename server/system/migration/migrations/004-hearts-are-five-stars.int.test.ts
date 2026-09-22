import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { heartsAreFiveStars } = await import(
  '~/system/migration/migrations/004-hearts-are-five-stars'
)

const EARLIER = new Date('2026-03-01T10:00:00.000Z')

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const run = () => heartsAreFiveStars.migrate({ db: fakeDb() })

describe('making every stored heart five stars', () => {
  test('rates a favourite book five and marks it read, as a heart now does', async () => {
    fake.seed('books', 'pile', { userId: 'r', status: 'to-read', favorite: true })
    fake.seed('books', 'reading', {
      userId: 'r',
      status: 'reading',
      favorite: true,
      rating: 3,
      startedAt: EARLIER,
    })

    const result = await run()

    expect(result).toEqual({ ok: true, transformed: 2 })
    const pile = fake.data('books', 'pile')
    expect(pile).toMatchObject({ rating: 5, status: 'read', favorite: true })
    expect(pile?.startedAt).toBeInstanceOf(Date)
    expect(pile?.finishedAt).toBeInstanceOf(Date)
    expect(pile?.statusChangedAt).toBeInstanceOf(Date)
    const reading = fake.data('books', 'reading')
    expect(reading).toMatchObject({ rating: 5, status: 'read' })
    // The start the reader gave is theirs: only the missing dates are stamped.
    expect(reading?.startedAt).toEqual(EARLIER)
  })

  test('keeps a read book dates and a dropped book status', async () => {
    fake.seed('books', 'read', {
      userId: 'r',
      status: 'read',
      favorite: true,
      rating: 4,
      startedAt: EARLIER,
      finishedAt: EARLIER,
      statusChangedAt: EARLIER,
    })
    fake.seed('books', 'dropped', { userId: 'r', status: 'dropped', favorite: true })

    await run()

    expect(fake.data('books', 'read')).toMatchObject({ rating: 5, status: 'read' })
    expect(fake.data('books', 'read')?.finishedAt).toEqual(EARLIER)
    expect(fake.data('books', 'read')?.statusChangedAt).toEqual(EARLIER)
    expect(fake.data('books', 'dropped')).toMatchObject({ rating: 5, status: 'dropped' })
    expect(fake.data('books', 'dropped')?.finishedAt).toBeUndefined()
  })

  test('leaves alone a book with no heart, or one already on five stars', async () => {
    fake.seed('books', 'plain', { userId: 'r', status: 'to-read', rating: 2 })
    fake.seed('books', 'done', { userId: 'r', status: 'read', favorite: true, rating: 5 })

    const result = await run()

    expect(result).toEqual({ ok: true, transformed: 0 })
    expect(fake.data('books', 'plain')).toMatchObject({ status: 'to-read', rating: 2 })
  })

  test('rates a favourite saga five', async () => {
    fake.seed('series-opinions', 'r_dune', { userId: 'r', seriesId: 'dune', favorite: true })
    fake.seed('series-opinions', 'r_hyp', { userId: 'r', seriesId: 'hyp', rating: 3 })

    const result = await run()

    expect(result).toEqual({ ok: true, transformed: 1 })
    expect(fake.data('series-opinions', 'r_dune')).toMatchObject({ rating: 5, favorite: true })
    expect(fake.data('series-opinions', 'r_hyp')).toMatchObject({ rating: 3 })
  })

  // The dashboard counts ratings and read books: every reader touched gets a
  // rebuilt view on their next visit.
  test('marks the dashboard of every reader touched stale', async () => {
    fake.seed('books', 'a', { userId: 'r1', status: 'to-read', favorite: true })
    fake.seed('series-opinions', 'r2_dune', { userId: 'r2', seriesId: 'dune', favorite: true })
    fake.seed('books', 'b', { userId: 'r3', status: 'to-read' })

    await run()

    expect(fake.data('analytics', 'r1')).toMatchObject({ stale: true })
    expect(fake.data('analytics', 'r2')).toMatchObject({ stale: true })
    expect(fake.data('analytics', 'r3')).toBeNull()
  })
})
