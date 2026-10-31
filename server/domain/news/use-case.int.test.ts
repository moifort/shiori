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

const { NewsUseCase } = await import('~/domain/news/use-case')

const reader = 'reader' as UserId
const marc = 'marc' as UserId
const sophie = 'sophie' as UserId
const yesterday = new Date('2026-10-30T09:00:00Z')
let fake: FakeFirestore

const shelve = (id: string, owner: UserId, title: string, extra: Record<string, unknown>) =>
  fake.seed('books', id, {
    id,
    userId: owner,
    title,
    authors: ['Auteur'],
    format: 'book',
    media: ['print'],
    subgenres: [],
    narrators: [],
    language: 'fr',
    status: 'read',
    hidden: false,
    addedAt: yesterday,
    ...extra,
  })

beforeEach(() => {
  fake = resetFakeFirestore()
  for (const friend of [marc, sophie]) {
    fake.seed('friendships', `${friend}--reader`, {
      id: `${friend}--reader`,
      userIds: [friend, reader],
      since: yesterday,
    })
    fake.seed('users', friend, { userId: friend, firstName: friend })
  }
  shelve('m1', marc, 'Vagabond', {
    status: 'reading',
    startedAt: yesterday,
  })
  shelve('m2', marc, 'Arabe', {
    rating: 5,
    favorite: true,
    favoritedAt: new Date('2026-10-31T06:00:00Z'),
    finishedAt: new Date('2026-10-31T06:00:00Z'),
  })
  shelve('m3', marc, 'Secret', { status: 'reading', startedAt: yesterday, hidden: true })
  shelve('s1', sophie, 'Vagabond', { status: 'reading', startedAt: yesterday })
  shelve('r1', reader, 'Vagabond', {})
})

describe('the news feed', () => {
  test('merges the friends, hides what they keep to themselves and carries the stars', async () => {
    const page = await NewsUseCase.feed(reader, 20)
    const ids = page.events.map((event) => event.id)
    expect(ids).toContain('marc~loved~m2')
    expect(ids).not.toContain('marc~started~m3')
    const vagabond = page.events.find((event) => event.id === 'sophie~started~s1')
    expect(vagabond?.alsoStartedBy).toBe(1)
    expect(vagabond?.inLibrary).toBe(true)
    expect(page.events.find((event) => event.kind === 'loved')?.rating).toBe(5 as never)
  })

  test('reads a constant number of documents, whatever the size of the page', async () => {
    const measure = async (limit: number) => {
      const before = { queries: fake.queryReads, docs: fake.queriedDocs }
      await inConcurrentFakeRequests([() => NewsUseCase.feed(reader, limit)])
      return { queries: fake.queryReads - before.queries, docs: fake.queriedDocs - before.docs }
    }
    // The first read builds the friends' stored views; the budget is the steady state.
    await measure(1)
    const small = await measure(1)
    const large = await measure(50)
    expect(large).toEqual(small)
    // Friendships, the reader's library, the names, the stored views and the
    // two shelves rebuilt: never a read per event.
    expect(small.queries).toBeLessThanOrEqual(8)
  })

  test('pages by cursor', async () => {
    const first = await NewsUseCase.feed(reader, 1)
    expect(first.events).toHaveLength(1)
    expect(first.nextCursor).toBeDefined()
    const second = await NewsUseCase.feed(reader, 1, first.nextCursor)
    expect(second.events[0]?.id).not.toBe(first.events[0]?.id)
  })
})
