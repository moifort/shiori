import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { booksCarryTheirShelfDate } = await import(
  '~/system/migration/migrations/005-books-carry-their-shelf-date'
)

const ADDED = new Date('2026-01-01T10:00:00.000Z')
const STARTED = new Date('2026-02-01T10:00:00.000Z')
const FINISHED = new Date('2026-03-01T10:00:00.000Z')

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const run = () => booksCarryTheirShelfDate.migrate({ db: fakeDb() })

describe('stamping every book with its shelf date', () => {
  test('takes the finish, else the start, else the day it was added', async () => {
    fake.seed('books', 'read', {
      userId: 'r',
      addedAt: ADDED,
      startedAt: STARTED,
      finishedAt: FINISHED,
    })
    fake.seed('books', 'reading', { userId: 'r', addedAt: ADDED, startedAt: STARTED })
    fake.seed('books', 'pile', { userId: 'r', addedAt: ADDED })

    expect(await run()).toEqual({ ok: true, transformed: 3 })
    expect(fake.data('books', 'read')?.shelvedAt).toEqual(FINISHED)
    expect(fake.data('books', 'reading')?.shelvedAt).toEqual(STARTED)
    expect(fake.data('books', 'pile')?.shelvedAt).toEqual(ADDED)
  })

  test('leaves a book already stamped alone, so a second run changes nothing', async () => {
    fake.seed('books', 'read', { userId: 'r', addedAt: ADDED, shelvedAt: STARTED })

    expect(await run()).toEqual({ ok: true, transformed: 0 })
    expect(fake.data('books', 'read')?.shelvedAt).toEqual(STARTED)
  })

  test('writes past the 500 a single batch accepts', async () => {
    for (let index = 0; index < 650; index++)
      fake.seed('books', `book-${index}`, { userId: 'r', addedAt: ADDED })

    expect(await run()).toEqual({ ok: true, transformed: 650 })
  })
})
