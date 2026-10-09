import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { volumesNumberedThroughTheirSaga } = await import(
  '~/system/migration/migrations/020-volumes-numbered-through-their-saga'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const run = () => volumesNumberedThroughTheirSaga.migrate({ db: fakeDb() })

const benton = 'sir-arthur-benton--tarek'
const membership = (volume: number) => ({
  id: benton,
  name: 'Sir Arthur Benton',
  volume,
  kind: 'main',
})

describe('volumes numbered through their saga', () => {
  beforeEach(() => {
    fake.seed('series', `${benton}~fr`, {
      name: 'Sir Arthur Benton',
      author: 'Tarek',
      language: 'fr',
      volumes: [
        { number: 1, title: 'Opération Marmara', kind: 'main' },
        { number: 2, title: 'Wannsee, 1942', kind: 'main' },
        { number: 4, title: "L'Organisation", kind: 'main' },
        { number: 5, title: 'Le Coup de Prague', kind: 'main' },
        { number: 6, title: "La Mort de l'oncle Joe", kind: 'main' },
      ],
    })
  })

  test('a volume numbered within its cycle takes its number in the saga', async () => {
    fake.seed('books', 'prague', {
      userId: 'r',
      language: 'fr',
      title: 'Le Coup de Prague',
      series: membership(2),
    })
    fake.seed('books', 'joe', {
      userId: 'r',
      language: 'fr',
      title: "La Mort de l'Oncle Joe",
      series: membership(3),
    })
    fake.seed('books', 'organisation', {
      userId: 'r',
      language: 'fr',
      title: "L'Organisation",
      series: membership(4),
    })

    expect(await run()).toEqual({ ok: true, transformed: 2 })
    expect(fake.data('books', 'prague')?.series).toEqual(membership(5))
    expect(fake.data('books', 'joe')?.series).toEqual(membership(6))
    expect(fake.data('books', 'organisation')?.series).toEqual(membership(4))
    expect(fake.data('analytics', 'r')).toMatchObject({ userId: 'r', stale: true })
  })

  test('a book of another edition, or titled like no volume, is left alone', async () => {
    fake.seed('books', 'english', {
      userId: 'r',
      language: 'en',
      title: 'Le Coup de Prague',
      series: membership(2),
    })
    fake.seed('books', 'unknown', {
      userId: 'r',
      language: 'fr',
      title: 'Un inédit',
      series: membership(3),
    })

    expect(await run()).toEqual({ ok: true, transformed: 0 })
    expect(fake.data('books', 'english')?.series).toEqual(membership(2))
    expect(fake.data('analytics', 'r')).toBeNull()
  })
})
