import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { heldWishesForgotten } = await import(
  '~/system/migration/migrations/038-held-wishes-forgotten'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const wishedAt = new Date('2026-11-01T08:00:00Z')

const seedWish = (userId: string, title: string, author: string) =>
  fake.seed('wishes', `${userId}--${title}`, { userId, title, authors: [author], wishedAt })

describe('held wishes forgotten', () => {
  test('deletes the wishes whose story the reader holds, and theirs alone', async () => {
    seedWish('bob', 'Piranesi', 'Susanna Clarke')
    seedWish('bob', 'Jonathan Strange', 'Susanna Clarke')
    seedWish('ann', 'Piranesi', 'Susanna Clarke')
    fake.seed('books', 'b1', { userId: 'bob', title: 'PIRANESI', authors: ['Susanna  Clarke'] })

    const result = await heldWishesForgotten.migrate({ db: fakeDb() })

    expect(result).toEqual({ ok: true, transformed: 1 })
    expect([...fake.snapshot('wishes').keys()].sort()).toEqual([
      'ann--Piranesi',
      'bob--Jonathan Strange',
    ])
  })

  test('changes nothing when run again', async () => {
    seedWish('bob', 'Piranesi', 'Susanna Clarke')
    fake.seed('books', 'b1', { userId: 'bob', title: 'Piranesi', authors: ['Susanna Clarke'] })
    await heldWishesForgotten.migrate({ db: fakeDb() })

    expect(await heldWishesForgotten.migrate({ db: fakeDb() })).toEqual({
      ok: true,
      transformed: 0,
    })
  })
})
