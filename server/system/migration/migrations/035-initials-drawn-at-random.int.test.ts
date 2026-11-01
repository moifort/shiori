import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { AVATAR_COLORS } from '~/domain/user/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

const removed: string[] = []

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/object-store', () => ({
  objectStore: () => ({
    remove: async (path: string) => {
      removed.push(path)
    },
  }),
}))

const { initialsDrawnAtRandom } = await import(
  '~/system/migration/migrations/035-initials-drawn-at-random'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
  removed.length = 0
})

const profile = (userId: string, extra: object = {}) => ({
  userId,
  firstName: 'Thibaut',
  onboardingCompletedAt: new Date('2026-10-01'),
  ...extra,
})

describe('initials drawn at random', () => {
  test('puts a hero, a photo and a bare profile on a coloured initial', async () => {
    fake.seed('users', 'u1', profile('u1', { avatar: { kind: 'hero', hero: 'alice' } }))
    fake.seed('users', 'u2', profile('u2', { avatar: { kind: 'photo', path: 'avatars/u2/1.jpg' } }))
    fake.seed('users', 'u3', profile('u3'))

    const result = await initialsDrawnAtRandom.migrate({ db: fakeDb() })

    expect(result).toEqual({ ok: true, transformed: 3 })
    for (const id of ['u1', 'u2', 'u3']) {
      const avatar = fake.data('users', id)?.avatar as { kind: string; color: string }
      expect(avatar.kind).toBe('initials')
      expect(AVATAR_COLORS).toContain(avatar.color as never)
      expect(fake.data('users', id)?.firstName).toBe('Thibaut')
    }
  })

  test('deletes the photos it replaces, and only those', async () => {
    fake.seed('users', 'u1', profile('u1', { avatar: { kind: 'photo', path: 'avatars/u1/1.jpg' } }))
    fake.seed('users', 'u2', profile('u2', { avatar: { kind: 'hero', hero: 'alice' } }))

    await initialsDrawnAtRandom.migrate({ db: fakeDb() })

    expect(removed).toEqual(['avatars/u1/1.jpg'])
  })

  test('leaves a colour already chosen alone, so a second run changes nothing', async () => {
    const pink = { kind: 'initials', color: 'pink' }
    fake.seed('users', 'u1', profile('u1', { avatar: pink }))

    const result = await initialsDrawnAtRandom.migrate({ db: fakeDb() })

    expect(result).toEqual({ ok: true, transformed: 0 })
    expect(fake.data('users', 'u1')?.avatar).toEqual(pink)
  })
})
