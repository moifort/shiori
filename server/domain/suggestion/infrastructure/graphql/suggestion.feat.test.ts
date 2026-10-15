import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { graphql } from 'graphql'
import type { UserId } from '~/domain/shared/types'
import { type FakeFirestore, fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/object-store', () => ({
  objectStore: () => ({ downloadUrl: async () => 'https://fake.store/cover' }),
}))
mock.module('~/system/identity', () => ({ deleteAuthUser: async () => undefined }))
mock.module('~/domain/suggestion/infrastructure/claude', () => ({
  isConfigured: () => true,
  ask: async () =>
    JSON.stringify([
      {
        title: 'La Sanction',
        originalTitle: 'The Eiger Sanction',
        author: 'Trevanian',
        language: 'en',
        kind: 'novel',
        reason: 'Espionnage et alpinisme, après Shibumi.',
        short: 'comme Shibumi',
        references: ['Shibumi'],
      },
    ]),
}))
mock.module('~/domain/suggestion/infrastructure/catalogue', () => ({
  catalogueEntryOf: async () => ({ known: true, coverUrl: 'https://covers.example/eiger.jpg' }),
}))
const { schema } = await import('~/domain/shared/graphql/schema')

const reader = 'reader' as UserId
const french = { node: { req: { headers: { 'accept-language': 'fr-FR' } } } }
const ask = (source: string, variableValues?: Record<string, unknown>) =>
  graphql({ schema, source, contextValue: { event: french, userId: reader }, variableValues })

let fake: FakeFirestore

beforeEach(() => {
  fake = resetFakeFirestore()
  fake.seed('books', 'shibumi', {
    id: 'shibumi',
    userId: reader,
    title: 'Shibumi',
    authors: ['Trevanian'],
    format: 'book',
    media: ['print'],
    subgenres: [],
    narrators: [],
    language: 'fr',
    status: 'read',
    rating: 5,
    favorite: true,
    hidden: false,
    addedAt: new Date(),
  })
})

const DISCOVERIES = `query {
  monthlyDiscoveries(format: BOOK) {
    month
    suggestions {
      id title originalTitle originalLanguage authors kind reason short coverUrl
      awaitableFormats state watched
      references { bookId title favorite rating viaSeries }
    }
  }
}`

describe('monthlyDiscoveries', () => {
  test('answers the month and each suggestion with why and its references', async () => {
    const { data, errors } = await ask(DISCOVERIES)

    expect(errors).toBeUndefined()
    const discoveries = data?.monthlyDiscoveries as {
      month: string
      suggestions: Record<string, unknown>[]
    }
    expect(discoveries.month).toMatch(/^\d{4}-\d{2}$/)
    expect(discoveries.suggestions).toEqual([
      {
        id: 'eiger-sanction--trevanian',
        title: 'La Sanction',
        originalTitle: 'The Eiger Sanction',
        originalLanguage: 'EN',
        authors: ['Trevanian'],
        kind: 'NOVEL',
        reason: 'Espionnage et alpinisme, après Shibumi.',
        short: 'comme Shibumi',
        coverUrl: 'https://covers.example/eiger.jpg',
        awaitableFormats: ['BOOK', 'AUDIOBOOK'],
        state: 'UNANNOUNCED',
        watched: false,
        references: [
          { bookId: 'shibumi', title: 'Shibumi', favorite: true, rating: 5, viaSeries: false },
        ],
      },
    ])
  })
})

describe('dismissSuggestion', () => {
  test('takes the suggestion off the line for good', async () => {
    await ask(DISCOVERIES)
    const dismissed = await ask('mutation ($id: String!) { dismissSuggestion(id: $id) }', {
      id: 'eiger-sanction--trevanian',
    })
    expect(dismissed.errors).toBeUndefined()
    const { data } = await ask(DISCOVERIES)
    expect(data?.monthlyDiscoveries).toEqual({ month: expect.any(String), suggestions: [] })
  })

  test('is NOT_FOUND for a suggestion the reader does not have', async () => {
    const { errors } = await ask('mutation { dismissSuggestion(id: "nothing") }')
    expect(errors?.[0]?.extensions?.code).toBe('NOT_FOUND')
  })
})
