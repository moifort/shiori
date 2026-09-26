import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { booksCarryTheirSagaName } = await import(
  '~/system/migration/migrations/010-books-carry-their-saga-name'
)

const SAGA = 'red-rising-french-edition--pierre-brown--audio'

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const run = () => booksCarryTheirSagaName.migrate({ db: fakeDb() })

const volume = (id: string, seriesId: string, name: string) =>
  fake.seed('books', id, {
    userId: 'r',
    format: 'audiobook',
    series: { id: seriesId, name, volume: 1, kind: 'main' },
  })

describe('naming the books after their saga', () => {
  test('gives every book of a catalogued saga the catalogue’s name', async () => {
    fake.seed('series', SAGA, { name: 'Red Rising', author: 'Pierre Brown', volumes: [] })
    volume('one', SAGA, 'Red Rising[French Edition]')
    volume('two', SAGA, 'Red Rising')
    volume('other', 'bobiverse--dennis-e-taylor--audio', 'Bobiverse {French Edition}')
    fake.seed('books', 'standalone', { userId: 'r', format: 'book' })

    expect(await run()).toEqual({ ok: true, transformed: 1 })
    expect(fake.data('books', 'one')?.series).toEqual({
      id: SAGA,
      name: 'Red Rising',
      volume: 1,
      kind: 'main',
    })
    // No catalogue: the name the books gave it stands.
    expect(fake.data('books', 'other')?.series).toEqual({
      id: 'bobiverse--dennis-e-taylor--audio',
      name: 'Bobiverse {French Edition}',
      volume: 1,
      kind: 'main',
    })
    expect(fake.data('books', 'standalone')?.series).toBeUndefined()
  })
})
