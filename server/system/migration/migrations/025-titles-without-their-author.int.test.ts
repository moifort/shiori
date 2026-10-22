import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { titlesWithoutTheirAuthor } = await import(
  '~/system/migration/migrations/025-titles-without-their-author'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const run = () => titlesWithoutTheirAuthor.migrate({ db: fakeDb() })

describe('titles without their author', () => {
  test('drops the author the lookup left at the end of a title', async () => {
    fake.seed('books', 'horde', {
      userId: 'r',
      title: 'La Horde du Contrevent — Alain Damasio',
      authors: ['Alain Damasio'],
    })

    expect(await run()).toEqual({ ok: true, transformed: 1 })
    expect(fake.data('books', 'horde')?.title).toBe('La Horde du Contrevent')
  })

  test('keeps a dash that names something other than the book’s author', async () => {
    fake.seed('books', 'dash', {
      userId: 'r',
      title: 'Dune — Le Messie',
      authors: ['Frank Herbert'],
    })
    fake.seed('books', 'plain', { userId: 'r', title: 'Neuromancien', authors: ['William Gibson'] })

    expect(await run()).toEqual({ ok: true, transformed: 0 })
    expect(fake.data('books', 'dash')?.title).toBe('Dune — Le Messie')
  })
})
