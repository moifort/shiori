import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { titleCaseSubgenres } = await import(
  '~/system/migration/migrations/002-title-case-subgenres'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const subgenresOf = async (id: string) =>
  (await fakeDb().collection('books').doc(id).get()).data()?.subgenres

describe('title-casing the stored subgenres', () => {
  test('rewrites every label and folds two spellings of one', async () => {
    fake.seed('books', 'a', { userId: 'r', subgenres: ['dark fantasy', 'Dark Fantasy', 'LitRPG'] })
    fake.seed('books', 'b', { userId: 'r', subgenres: ['Space Opera'] })
    fake.seed('books', 'c', { userId: 'r', subgenres: [] })

    expect(await titleCaseSubgenres.migrate({ db: fakeDb() as never })).toEqual({
      ok: true,
      transformed: 1,
    })
    expect(await subgenresOf('a')).toEqual(['Dark Fantasy', 'LitRPG'])
    expect(await subgenresOf('b')).toEqual(['Space Opera'])
  })
})
