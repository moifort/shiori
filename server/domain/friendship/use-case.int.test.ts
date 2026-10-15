import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import {
  type FakeFirestore,
  fakeDb,
  inConcurrentFakeRequests,
  resetFakeFirestore,
} from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/object-store', () => ({
  objectStore: () => ({ downloadUrl: async () => 'https://fake.store/cover' }),
}))

const { FriendshipUseCase } = await import('~/domain/friendship/use-case')

const reader = 'reader' as UserId
const friend = 'friend' as UserId
const now = new Date('2026-10-15T16:00:00Z')
const yesterday = new Date('2026-10-14T16:00:00Z')
let fake: FakeFirestore
let shelved = 0

const shelve = (owner: UserId, title: string, favorite = false) => {
  shelved += 1
  fake.seed('books', `book-${shelved}`, {
    id: `book-${shelved}`,
    userId: owner,
    title,
    authors: ['Dan Simmons'],
    format: 'book',
    media: ['print'],
    genre: 'science-fiction',
    subgenres: [],
    narrators: [],
    language: 'fr',
    status: 'read',
    hidden: false,
    addedAt: yesterday,
    ...(favorite ? { favorite: true, favoritedAt: yesterday } : {}),
  })
}

beforeEach(() => {
  fake = resetFakeFirestore()
  shelved = 0
  fake.seed('friendships', 'friend--reader', {
    id: 'friend--reader',
    userIds: [friend, reader],
    since: yesterday,
  })
  fake.seed('users', friend, { userId: friend, firstName: 'Camille' })
  shelve(reader, 'Hypérion')
  shelve(reader, 'La Chute d’Hypérion')
  shelve(friend, 'Endymion', true)
  shelve(friend, 'L’Éveil d’Endymion')
  shelve(friend, 'Ilium')
})

describe('the friends’ hearts, asked for together', () => {
  /** The dashboard's news and Découvrir's shelf, each as its own request. Each
   *  reads the friendships, the reader's library, and the friend's shelf and
   *  saga opinions: one document, two, three and none. */
  const favorites = () => FriendshipUseCase.recentFavorites(reader, now)
  const recommendations = () => FriendshipUseCase.recommendations(reader)
  const reads = () => ({ queries: fake.queryReads, docs: fake.queriedDocs })

  test('one after the other, each reads both libraries', async () => {
    const before = reads()

    const [hearts] = await inConcurrentFakeRequests([favorites])
    await inConcurrentFakeRequests([recommendations])

    expect(hearts).toHaveLength(1)
    expect(fake.queryReads - before.queries).toBe(8)
    expect(fake.queriedDocs - before.docs).toBe(2 * (1 + 2 + 3))
  })

  test('sent together, they read each library once between them', async () => {
    fake.answerQueriesAfter(10)
    const before = reads()

    await inConcurrentFakeRequests<unknown>([favorites, recommendations])

    expect(fake.queryReads - before.queries).toBe(4)
    expect(fake.queriedDocs - before.docs).toBe(1 + 2 + 3)
  })
})
