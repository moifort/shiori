import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { graphql } from 'graphql'
import type { UserId } from '~/domain/shared/types'
import { type FakeFirestore, fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/object-store', () => ({
  objectStore: () => ({ downloadUrl: async () => 'https://fake.store/cover' }),
}))
mock.module('~/system/identity', () => ({ deleteAuthUser: async () => undefined }))
const { schema } = await import('~/domain/shared/graphql/schema')

const reader = 'reader' as UserId
const marc = 'marc' as UserId
const french = { node: { req: { headers: { 'accept-language': 'fr-FR' } } } }
const ask = (source: string, variableValues?: Record<string, unknown>) =>
  graphql({ schema, source, contextValue: { event: french, userId: reader }, variableValues })

let fake: FakeFirestore
const when = new Date('2026-10-30T09:00:00Z')

beforeEach(() => {
  fake = resetFakeFirestore()
  fake.seed('friendships', 'marc--reader', {
    id: 'marc--reader',
    userIds: [marc, reader],
    since: when,
  })
  fake.seed('users', marc, {
    userId: marc,
    firstName: 'Marc',
    avatar: { kind: 'hero', hero: 'holmes' },
  })
  const book = (id: string, extra: Record<string, unknown>) =>
    fake.seed('books', id, {
      id,
      userId: marc,
      title: id,
      authors: ['Auteur'],
      format: 'book',
      media: ['print'],
      subgenres: [],
      narrators: [],
      language: 'fr',
      status: 'read',
      hidden: false,
      addedAt: when,
      ...extra,
    })
  book('Arabe', { rating: 5, favorite: true, favoritedAt: when, finishedAt: when })
  book('Secret', { status: 'reading', startedAt: when, hidden: true })
})

describe('newsFeed', () => {
  test('tells what a friend loved, with the stars, and never what they hide', async () => {
    const { data, errors } = await ask(`{
      newsFeed(limit: 10) {
        nextCursor
        events { kind friendFirstName friendAvatarHero friendAvatarColor title rating inLibrary alsoStartedBy coverUrl }
      }
    }`)
    expect(errors).toBeUndefined()
    const events = (data as { newsFeed: { events: { kind: string; title: string }[] } }).newsFeed
      .events
    expect(events.map((event) => event.title)).toEqual(['Arabe'])
    expect(events[0]).toMatchObject({
      kind: 'LOVED',
      friendFirstName: 'Marc',
      friendAvatarHero: 'HOLMES',
      friendAvatarColor: null,
      rating: 5,
    })
  })
})

describe('upcomingReleases', () => {
  test('answers an empty calendar for a reader who follows nothing', async () => {
    const { data, errors } = await ask(
      '{ upcomingReleases(format: BOOK) { id title date source format } }',
    )
    expect(errors).toBeUndefined()
    expect(data).toEqual({ upcomingReleases: [] })
  })
})
