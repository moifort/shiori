import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/object-store', () => ({
  objectStore: () => ({ removeByPrefix: async () => undefined }),
}))
mock.module('~/system/identity', () => ({ deleteAuthUser: async () => undefined }))

const { UserUseCase } = await import('~/domain/user/use-case')

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
  'saga-watches',
  'scan-cache',
  'series',
  'series-misses',
  // Its documents name two readers in `userIds`, seeded apart below.
  'friendships',
])

// The collections the domains' repositories open, read from their source, so a
// collection added later fails here until it is classified above.
const collectionsInUse = () => {
  const root = join(import.meta.dir, '..')
  const found = new Set<string>()
  for (const file of new Bun.Glob('*/infrastructure/*repository.ts').scanSync(root)) {
    const source = readFileSync(join(root, file), 'utf8')
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
