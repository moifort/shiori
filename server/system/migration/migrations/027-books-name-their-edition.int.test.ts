import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { booksNameTheirEdition } = await import(
  '~/system/migration/migrations/027-books-name-their-edition'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const run = () => booksNameTheirEdition.migrate({ db: fakeDb() })

const DUNE = 'dune--frank-herbert'

describe('books name their edition', () => {
  test('names each book by the edition its language makes, the saga kept beside', async () => {
    fake.seed('books', 'fr', {
      userId: 'r',
      language: 'fr',
      series: { id: DUNE, name: 'Dune', volume: 1, kind: 'main' },
    })
    fake.seed('books', 'en', {
      userId: 'r',
      language: 'en',
      series: { id: DUNE, name: 'Dune', volume: 2, kind: 'main' },
    })
    fake.seed('books', 'heard', {
      userId: 'r',
      language: 'en',
      series: { id: `${DUNE}--audio`, name: 'Dune', volume: 1, kind: 'main' },
    })

    expect(await run()).toEqual({ ok: true, transformed: 3 })
    expect(fake.data('books', 'fr')?.series).toEqual({
      id: `${DUNE}~fr`,
      saga: DUNE,
      name: 'Dune',
      volume: 1,
      kind: 'main',
    })
    expect(fake.data('books', 'en')?.series).toMatchObject({ id: `${DUNE}~en`, saga: DUNE })
    expect(fake.data('books', 'heard')?.series).toMatchObject({
      id: `${DUNE}--audio~en`,
      saga: `${DUNE}--audio`,
    })
  })

  test('names a book with no language as a French one, as it reads', async () => {
    fake.seed('books', 'bare', {
      userId: 'r',
      series: { id: DUNE, name: 'Dune', kind: 'main' },
    })

    await run()
    expect(fake.data('books', 'bare')?.series).toMatchObject({ id: `${DUNE}~fr`, saga: DUNE })
  })

  test('leaves standalone books and books already named alone', async () => {
    fake.seed('books', 'standalone', { userId: 'r', language: 'fr' })
    fake.seed('books', 'done', {
      userId: 'r',
      language: 'fr',
      series: { id: `${DUNE}~fr`, saga: DUNE, name: 'Dune', kind: 'main' },
    })

    expect(await run()).toEqual({ ok: true, transformed: 0 })
  })

  test('gives each catalogue and miss its series id and its saga', async () => {
    fake.seed('series', `${DUNE}~fr`, { id: DUNE, language: 'fr', name: 'Dune', volumes: [] })
    fake.seed('series', DUNE, { id: DUNE, name: 'Dune', volumes: [] })
    fake.seed('series-misses', `${DUNE}--audio~en`, {
      id: `${DUNE}--audio`,
      language: 'en',
      missedAt: new Date('2026-10-01'),
    })

    expect(await run()).toEqual({ ok: true, transformed: 3 })
    expect(fake.data('series', `${DUNE}~fr`)).toMatchObject({
      id: `${DUNE}~fr`,
      saga: DUNE,
      language: 'fr',
      name: 'Dune',
    })
    expect(fake.data('series', DUNE)).toMatchObject({ id: DUNE, saga: DUNE })
    expect(fake.data('series-misses', `${DUNE}--audio~en`)).toMatchObject({
      id: `${DUNE}--audio~en`,
      saga: `${DUNE}--audio`,
    })
  })

  test('changes nothing on a second run', async () => {
    fake.seed('books', 'fr', {
      userId: 'r',
      language: 'fr',
      series: { id: DUNE, name: 'Dune', kind: 'main' },
    })
    fake.seed('series', `${DUNE}~fr`, { id: DUNE, language: 'fr', name: 'Dune', volumes: [] })

    expect(await run()).toEqual({ ok: true, transformed: 2 })
    expect(await run()).toEqual({ ok: true, transformed: 0 })
  })
})
