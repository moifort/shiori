import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { titlesWithoutTheirSaga } = await import(
  '~/system/migration/migrations/018-titles-without-their-saga'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const run = () => titlesWithoutTheirSaga.migrate({ db: fakeDb() })

describe('titles without their saga', () => {
  test('a book keeps the title alone, a book outside any saga is left alone', async () => {
    fake.seed('books', 'crescent', {
      userId: 'r',
      title: 'Crescent City, Tome 1 : Maison de la Terre et du Sang',
      series: { id: 'crescent-city--sarah-j-maas', name: 'Crescent City', volume: 1, kind: 'main' },
    })
    fake.seed('books', 'clean', {
      userId: 'r',
      title: 'Le Nom du vent',
      series: { id: 'chronique', name: 'Chronique du tueur de roi', volume: 1, kind: 'main' },
    })
    fake.seed('books', 'standalone', { userId: 'r', title: 'Fourth Wing, Tome 1' })

    expect(await run()).toEqual({ ok: true, transformed: 1 })
    expect(fake.data('books', 'crescent')?.title).toBe('Maison de la Terre et du Sang')
    expect(fake.data('books', 'clean')?.title).toBe('Le Nom du vent')
    expect(fake.data('books', 'standalone')?.title).toBe('Fourth Wing, Tome 1')
  })

  test('a catalogue titles its volumes, in every language, without the saga', async () => {
    fake.seed('series', 'old-boy--tsuchiya-garon~fr', {
      name: 'Old Boy',
      author: 'Tsuchiya Garon',
      language: 'fr',
      volumes: [
        { number: 1, title: 'Old Boy', kind: 'main' },
        {
          number: 2,
          title: 'Old Boy, tome 2',
          kind: 'main',
          titles: { fr: 'Old Boy T2' },
          releases: { fr: '2020' },
        },
      ],
    })
    fake.seed('series', 'dune--frank-herbert~fr', {
      name: 'Dune',
      author: 'Frank Herbert',
      language: 'fr',
      volumes: [{ number: 2, title: 'Le Messie de Dune', kind: 'main' }],
    })

    expect(await run()).toEqual({ ok: true, transformed: 1 })
    expect(fake.data('series', 'old-boy--tsuchiya-garon~fr')?.volumes).toEqual([
      { number: 1, title: 'Old Boy', kind: 'main' },
      {
        number: 2,
        title: 'Old Boy',
        kind: 'main',
        titles: { fr: 'Old Boy' },
        releases: { fr: '2020' },
      },
    ])
  })
})
