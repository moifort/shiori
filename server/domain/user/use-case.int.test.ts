import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore, startFakeRequest } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/object-store', () => ({
  objectStore: () => ({ removeByPrefix: async () => undefined }),
}))
mock.module('~/system/identity', () => ({ deleteAuthUser: async () => undefined }))

const { UserUseCase } = await import('~/domain/user/use-case')
const { PersonName } = await import('~/domain/shared/primitives')
const { UserQuery } = await import('~/domain/user/query')

const reader = 'reader-1' as UserId
const neighbour = 'reader-2' as UserId

// Every collection a reader's documents live in, with the id a document of
// theirs is stored under. An account deletion must leave none of them behind.
const perReader: Record<string, (userId: UserId) => string> = {
  users: (userId) => userId,
  books: (userId) => `${userId}-book`,
  'book-sync-removals': (userId) => `${userId}~kindle~B000`,
  analytics: (userId) => userId,
  entitlements: (userId) => userId,
  'ai-quotas': (userId) => `${userId}~2026-11`,
  'ai-credits': (userId) => userId,
  'audible-connections': (userId) => userId,
  'kindle-connections': (userId) => userId,
  'series-opinions': (userId) => `${userId}~saga`,
  'author-favorites': (userId) => `${userId}~author`,
  'narrator-favorites': (userId) => `${userId}~narrator`,
  'catalogue-corrections': (userId) => `${userId}~saga`,
  'friend-invitations': (userId) => `${userId}-code`,
  'notification-settings': (userId) => userId,
  'discovery-readers': (userId) => userId,
  'discovery-projections': (userId) => `${userId}~book`,
  'discovery-library-changes': (userId) => userId,
  'awaited-editions': (userId) => `${userId}-awaited`,
  wishes: (userId) => `${userId}-wish`,
  'award-dismissals': (userId) => `${userId}~award`,
  'suggestion-queues': (userId) => userId,
  'suggestion-dismissals': (userId) => `${userId}~book`,
}

// Shared by every reader and naming none: an account deletion leaves them.
const shared = new Set([
  'admin-metrics',
  'ai-usage',
  'author-misses',
  'author-watches',
  'authors',
  'award-winners',
  'discovery-pass',
  'edition-pass',
  'edition-watches',
  'grounding-months',
  'kindle-titles',
  'narrator-watches',
  'narrators',
  'release-descriptions',
  'releases',
  'saga-watches',
  'scan-cache',
  'series',
  'series-misses',
  // Its documents name two readers in `userIds`, seeded apart below.
  'friendships',
])

// The collections the repositories open, the domains' and the system services'
// (Gemini's grounded-call counter), read from their source, so a collection
// added later fails here until it is classified above.
const collectionsInUse = () => {
  const server = join(import.meta.dir, '..', '..')
  const found = new Set<string>()
  for (const pattern of ['domain/*/infrastructure/*repository.ts', 'system/*/repository.ts'])
    for (const file of new Bun.Glob(pattern).scanSync(server)) {
      const source = readFileSync(join(server, file), 'utf8')
      for (const [, name] of source.matchAll(/collection\('([^']+)'\)/g)) found.add(name)
    }
  return found
}

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

describe('deleting an account', () => {
  test('every collection a repository opens is known as per-reader or shared', () => {
    const unclassified = [...collectionsInUse()].filter(
      (name) => !(name in perReader) && !shared.has(name),
    )

    expect(unclassified).toEqual([])
  })

  test('leaves no document of the reader in any per-reader collection, and the neighbour’s', async () => {
    for (const [collection, idOf] of Object.entries(perReader)) {
      for (const userId of [reader, neighbour])
        fake.seed(collection, idOf(userId), { userId, key: 'seeded' })
    }
    fake.seed('friendships', 'friendship-1', { id: 'friendship-1', userIds: [reader, 'reader-3'] })
    fake.seed('friendships', 'friendship-2', {
      id: 'friendship-2',
      userIds: [neighbour, 'reader-3'],
    })

    await UserUseCase.deleteAccount(reader)

    const left = Object.entries(perReader).flatMap(([collection, idOf]) =>
      fake.data(collection, idOf(reader)) ? [collection] : [],
    )
    const lost = Object.entries(perReader).flatMap(([collection, idOf]) =>
      fake.data(collection, idOf(neighbour)) ? [] : [collection],
    )
    expect(left).toEqual([])
    expect(lost).toEqual([])
    expect(fake.data('friendships', 'friendship-1')).toBeNull()
    expect(fake.data('friendships', 'friendship-2')).not.toBeNull()
  })
})

describe('completing onboarding again', () => {
  test('changes the first name alone, keeping the avatar, the admin flag and the date', async () => {
    const completedAt = new Date('2026-10-01T08:00:00.000Z')
    fake.seed('users', reader, {
      userId: reader,
      firstName: 'Alice',
      onboardingCompletedAt: completedAt,
      admin: true,
      avatar: { kind: 'hero', hero: 'merlin' },
    })

    const profile = await UserUseCase.completeOnboarding(reader, { firstName: PersonName('Alix') })

    const stored = fake.data('users', reader)
    expect(stored?.firstName).toBe('Alix')
    expect(stored?.admin).toBe(true)
    expect(stored?.avatar).toEqual({ kind: 'hero', hero: 'merlin' })
    expect(stored?.onboardingCompletedAt).toEqual(completedAt)
    expect(profile.avatar).toEqual({ kind: 'hero', hero: 'merlin' })
  })

  test('writes the whole profile the first time', async () => {
    await UserUseCase.completeOnboarding(reader, { firstName: PersonName('Alice') })

    expect(fake.data('users', reader)?.firstName).toBe('Alice')
    expect(fake.data('users', reader)?.onboardingCompletedAt).toBeInstanceOf(Date)
  })
})

describe('changing the avatar', () => {
  test('keeps a first name changed after the request read the profile', async () => {
    fake.seed('users', reader, {
      userId: reader,
      firstName: 'Alice',
      onboardingCompletedAt: new Date('2026-10-01T08:00:00.000Z'),
    })
    startFakeRequest()
    // The request has the profile in hand when another one renames the reader.
    await UserQuery.me(reader)
    fake.seed('users', reader, { ...fake.data('users', reader), firstName: 'Alix' })

    await UserUseCase.changeAvatar(reader, { hero: 'merlin' })

    expect(fake.data('users', reader)?.firstName).toBe('Alix')
    expect(fake.data('users', reader)?.avatar).toEqual({ kind: 'hero', hero: 'merlin' })
  })
})
