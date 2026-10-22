import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { titlesSingleSpaced } = await import(
  '~/system/migration/migrations/026-titles-single-spaced'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const run = () => titlesSingleSpaced.migrate({ db: fakeDb() })

describe('titles single-spaced', () => {
  test('single-spaces the title, the authors and the saga name', async () => {
    fake.seed('books', 'nom', {
      userId: 'r',
      title: 'Le Nom  du\nvent ',
      authors: ['Patrick  Rothfuss'],
      series: { id: 's', name: 'Chronique du  tueur de roi', volume: 1 },
    })

    expect(await run()).toEqual({ ok: true, transformed: 1 })
    expect(fake.data('books', 'nom')).toMatchObject({
      title: 'Le Nom du vent',
      authors: ['Patrick Rothfuss'],
      series: { id: 's', name: 'Chronique du tueur de roi', volume: 1 },
    })
  })

  test('drops an author a store left beside the title', async () => {
    fake.seed('books', 'before', {
      userId: 'r',
      title: 'Damasio - La Horde du Contrevent',
      authors: ['Alain Damasio'],
    })
    fake.seed('books', 'brackets', {
      userId: 'r',
      title: 'Neuromancien (William Gibson)',
      authors: ['William Gibson'],
    })

    expect(await run()).toEqual({ ok: true, transformed: 2 })
    expect(fake.data('books', 'before')?.title).toBe('La Horde du Contrevent')
    expect(fake.data('books', 'brackets')?.title).toBe('Neuromancien')
  })

  test('leaves a clean book untouched', async () => {
    fake.seed('books', 'dash', {
      userId: 'r',
      title: 'Dune — Le Messie',
      authors: ['Frank Herbert'],
    })

    expect(await run()).toEqual({ ok: true, transformed: 0 })
  })
})
