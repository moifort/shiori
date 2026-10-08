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
const french = { node: { req: { headers: { 'accept-language': 'fr-FR' } } } }
const ask = (source: string, variableValues?: Record<string, unknown>) =>
  graphql({ schema, source, contextValue: { event: french, userId: reader }, variableValues })

let fake: FakeFirestore

const shelve = (id: string, title: string, author: string, status = 'read') =>
  fake.seed('books', id, {
    id,
    userId: reader,
    title,
    authors: [author],
    format: 'book',
    media: ['print'],
    genre: 'science-fiction',
    subgenres: [],
    narrators: [],
    language: 'fr',
    status,
    hidden: false,
    addedAt: new Date(),
  })

beforeEach(() => {
  fake = resetFakeFirestore()
  shelve('one', 'Fondation', 'Isaac Asimov')
  shelve('two', 'La Stratégie Ender', 'Orson Scott Card')
  shelve('three', 'Neuromancien', 'William Gibson')
  // The French edition of Neuromancer, out, as the hourly pass kept it.
  fake.seed('edition-watches', 'neuromancer--william-gibson--book--fr', {
    key: 'neuromancer--william-gibson--book--fr',
    title: 'Neuromancer',
    author: 'William Gibson',
    originalLanguage: 'en',
    format: 'book',
    language: 'fr',
    checkedAt: new Date(),
    found: { title: 'Neuromancien', date: '1985-01-01', isbn13: '9782290343890' },
  })
})

const SHELF = `
  query ($format: ReleaseFormat!, $genre: Genre) {
    awardShelf(format: $format, genre: $genre) {
      genre
      genres
      recent { id title originalTitle authors state watched awaitable awards { award year } }
      awards { award readCount total winners { title } }
    }
  }
`

describe('awardShelf', () => {
  test('lists the winners of the reader’s genre, in French where found', async () => {
    const result = await ask(SHELF, { format: 'BOOK' })
    expect(result.errors).toBeUndefined()
    const shelf = result.data?.awardShelf as {
      genre: string
      genres: string[]
      recent: { title: string; state: string; awaitable: boolean; awards: unknown[] }[]
      awards: { award: string; readCount: number; total: number; winners: { title: string }[] }[]
    }

    expect(shelf.genre).toBe('SCIENCE_FICTION')
    expect(shelf.genres).toEqual(['SCIENCE_FICTION'])
    expect(shelf.recent[0]).toMatchObject({
      title: 'The Everlasting',
      state: 'UNANNOUNCED',
      watched: false,
      awaitable: true,
      awards: [{ award: 'HUGO', year: 2026 }],
    })
    const hugo = shelf.awards.find((list) => list.award === 'HUGO')
    // Neuromancer is held in French, so it is read and not listed.
    expect(hugo?.readCount).toBe(1)
    expect(hugo?.winners.map((winner) => winner.title)).not.toContain('Neuromancien')
    expect(hugo?.winners.map((winner) => winner.title)).not.toContain('Neuromancer')
  })

  test('is null for a reader who reads no genre with awards enough', async () => {
    fake = resetFakeFirestore()
    shelve('one', 'Fondation', 'Isaac Asimov')
    const result = await ask(SHELF, { format: 'AUDIOBOOK' })
    expect(result.errors).toBeUndefined()
    expect(result.data?.awardShelf).toBeNull()
  })
})
