import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { PersonName, UserId } from '~/domain/shared/types'
import type { UserProfile } from '~/domain/user/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { UserQuery } = await import('~/domain/user/query')

const user = (id: string) => id as UserId

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

describe('UserQuery.me', () => {
  test('returns nulls when no profile exists — the app routes to onboarding', async () => {
    const me = await UserQuery.me(user('u1'))
    expect(me.userId).toBe(user('u1'))
    expect(me.firstName).toBeUndefined()
    expect(me.onboardingCompletedAt).toBeUndefined()
  })

  test('returns the firstName and timestamp once a profile is saved', async () => {
    const profile: UserProfile = {
      userId: user('u1'),
      firstName: 'Thibaut' as PersonName,
      onboardingCompletedAt: new Date('2026-01-01'),
    }
    fake.seed('user-profiles', 'u1', profile)

    const me = await UserQuery.me(user('u1'))
    expect(me.firstName as string).toBe('Thibaut')
    expect(me.onboardingCompletedAt).toEqual(new Date('2026-01-01'))
  })
})
