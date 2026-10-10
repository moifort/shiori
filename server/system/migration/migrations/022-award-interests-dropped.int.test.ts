import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { awardInterestsDropped } = await import(
  '~/system/migration/migrations/022-award-interests-dropped'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

describe('award interests dropped', () => {
  test('deletes every genre somebody looked at, and nothing else', async () => {
    fake.seed('award-interests', 'fantasy--fr', { genre: 'fantasy', language: 'fr' })
    fake.seed('award-interests', 'science-fiction--en', { genre: 'science-fiction' })
    fake.seed('edition-watches', 'w', { key: 'w' })

    expect(await awardInterestsDropped.migrate({ db: fakeDb() })).toEqual({
      ok: true,
      transformed: 2,
    })

    expect(fake.data('award-interests', 'fantasy--fr')).toBeNull()
    expect(fake.data('award-interests', 'science-fiction--en')).toBeNull()
    expect(fake.data('edition-watches', 'w')).not.toBeNull()
  })
})
