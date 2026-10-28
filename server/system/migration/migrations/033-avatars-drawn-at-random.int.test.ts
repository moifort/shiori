import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { AVATAR_HEROES } from '~/domain/user/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { avatarsDrawnAtRandom } = await import(
  '~/system/migration/migrations/033-avatars-drawn-at-random'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const profile = (userId: string, extra: object = {}) => ({
  userId,
  firstName: 'Thibaut',
  onboardingCompletedAt: new Date('2026-10-01'),
  ...extra,
})

describe('avatars drawn at random', () => {
  test('gives every bare profile one of the heroes', async () => {
    fake.seed('users', 'u1', profile('u1'))
    fake.seed('users', 'u2', profile('u2'))

    const result = await avatarsDrawnAtRandom.migrate({ db: fakeDb() })

    expect(result).toEqual({ ok: true, transformed: 2 })
    for (const id of ['u1', 'u2']) {
      const avatar = fake.data('users', id)?.avatar as { kind: string; hero: string }
      expect(avatar.kind).toBe('hero')
      expect(AVATAR_HEROES).toContain(avatar.hero as never)
      expect(fake.data('users', id)?.firstName).toBe('Thibaut')
    }
  })

  test('leaves an avatar already worn alone', async () => {
    const photo = { kind: 'photo', path: 'avatars/u1/1.jpg' }
    fake.seed('users', 'u1', profile('u1', { avatar: photo }))

    const result = await avatarsDrawnAtRandom.migrate({ db: fakeDb() })

    expect(result).toEqual({ ok: true, transformed: 0 })
    expect(fake.data('users', 'u1')?.avatar).toEqual(photo)
  })
})
