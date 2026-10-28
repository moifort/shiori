import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { graphql } from 'graphql'
import type { PersonName, UserId } from '~/domain/shared/types'
import type { UserProfile } from '~/domain/user/types'
import { type FakeFirestore, fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

const written: string[] = []
const removed: string[] = []

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/object-store', () => ({
  objectStore: () => ({
    write: async (path: string, body: Buffer, contentType: string) => {
      written.push(path)
      return { contentType, size: body.byteLength }
    },
    downloadUrl: async (path: string) => `https://fake.store/${path}`,
    remove: async (path: string) => {
      removed.push(path)
    },
    removeByPrefix: async () => undefined,
  }),
}))

const { schema } = await import('~/domain/shared/graphql/schema')

const reader = 'reader' as UserId
const jpeg = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0, 0x10]).toString('base64')
const png = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a]).toString('base64')

let fake: FakeFirestore

beforeEach(() => {
  fake = resetFakeFirestore()
  written.length = 0
  removed.length = 0
})

const onboard = () => {
  const profile: UserProfile = {
    userId: reader,
    firstName: 'Thibaut' as PersonName,
    onboardingCompletedAt: new Date('2026-10-01'),
  }
  fake.seed('users', reader, profile)
}

const change = (input: Record<string, unknown>) =>
  graphql({
    schema,
    source:
      'mutation Change($input: ChangeAvatarInput!) { changeAvatar(input: $input) { avatarHero avatarUrl firstName } }',
    contextValue: { event: {}, userId: reader },
    variableValues: { input },
  })

const me = (result: Awaited<ReturnType<typeof change>>) =>
  (result.data as { changeAvatar: { avatarHero: string | null; avatarUrl: string | null } })
    .changeAvatar

describe('changing the avatar', () => {
  test('wears a hero, kept by name only', async () => {
    onboard()

    const result = await change({ hero: 'TIME_TRAVELLER' })

    expect(result.errors).toBeUndefined()
    expect(me(result)).toEqual({
      avatarHero: 'TIME_TRAVELLER',
      avatarUrl: null,
      firstName: 'Thibaut',
    } as never)
    expect(written).toEqual([])
  })

  test('keeps a photo in the bucket and serves it signed', async () => {
    onboard()

    const result = await change({ photoBase64: jpeg })

    expect(result.errors).toBeUndefined()
    expect(written).toHaveLength(1)
    expect(written[0]).toStartWith('avatars/reader/')
    expect(me(result).avatarUrl).toBe(`https://fake.store/${written[0]}`)
    expect(me(result).avatarHero).toBeNull()
  })

  test('deletes the photo a hero replaces', async () => {
    onboard()
    await change({ photoBase64: jpeg })

    await change({ hero: 'HOLMES' })

    expect(removed).toEqual([written[0] as string])
  })

  test('falls back to the initials when given neither', async () => {
    onboard()
    await change({ hero: 'ALICE' })

    const result = await change({})

    expect(me(result)).toMatchObject({ avatarHero: null, avatarUrl: null })
  })

  test('refuses a hero and a photo at once, and anything but a JPEG', async () => {
    onboard()

    const both = await change({ hero: 'NEMO', photoBase64: jpeg })
    const notJpeg = await change({ photoBase64: png })

    expect(both.errors?.[0]?.extensions?.code).toBe('BAD_USER_INPUT')
    expect(notJpeg.errors?.[0]?.extensions?.code).toBe('BAD_USER_INPUT')
    expect(written).toEqual([])
  })

  // An avatar alone would make a profile with no onboarding behind it.
  test('needs a finished onboarding', async () => {
    const result = await change({ hero: 'LUPIN' })

    expect(result.errors?.[0]?.extensions?.code).toBe('NOT_FOUND')
    expect(fake.data('users', reader)).toBeNull()
  })
})
