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
  shelve('three', 'La Mort de l’auteur', 'Nnedi Okorafor')
  // The French edition of Death of the Author, out, as the awaited editions'
  // pass kept it once a reader awaited it.
  fake.seed('edition-watches', 'death-of-the-author--nnedi-okorafor--book--fr', {
    key: 'death-of-the-author--nnedi-okorafor--book--fr',
    title: 'Death of the Author',
    author: 'Nnedi Okorafor',
    originalLanguage: 'en',
    format: 'book',
    language: 'fr',
    checkedAt: new Date(),
    found: { title: 'La Mort de l’auteur', date: '2026-03-01', isbn13: '9782290343890' },
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
  test('lists the latest winners of the reader’s genre, in French where found', async () => {
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
    const locus = shelf.awards.find((list) => list.award === 'LOCUS_SF')
    // Death of the Author is held in French, so it is read and not listed.
    expect(locus).toMatchObject({ readCount: 1, total: 1, winners: [] })
  })

  test('is null for a reader who reads no genre with awards enough', async () => {
    fake = resetFakeFirestore()
    shelve('one', 'Fondation', 'Isaac Asimov')
    const result = await ask(SHELF, { format: 'AUDIOBOOK' })
    expect(result.errors).toBeUndefined()
    expect(result.data?.awardShelf).toBeNull()
  })
})

const SECTIONS = `
  query ($format: ReleaseFormat!) {
    awardSections(format: $format) {
      genre
      winners { title state awaitable awards { award year } }
    }
  }
`

describe('awardSections', () => {
  test('gives the reader’s genre a section of its latest winners', async () => {
    const result = await ask(SECTIONS, { format: 'BOOK' })
    expect(result.errors).toBeUndefined()
    const sections = result.data?.awardSections as {
      genre: string
      winners: { title: string; state: string; awaitable: boolean }[]
    }[]

    expect(sections.map((section) => section.genre)).toEqual(['SCIENCE_FICTION'])
    expect(sections[0]?.winners[0]).toMatchObject({
      title: 'The Everlasting',
      state: 'UNANNOUNCED',
      awaitable: true,
    })
    expect(sections[0]?.winners.map((winner) => winner.title)).not.toContain('La Mort de l’auteur')
  })

  test('is empty for a reader who reads no genre with awards enough', async () => {
    fake = resetFakeFirestore()
    shelve('one', 'Fondation', 'Isaac Asimov')
    const result = await ask(SECTIONS, { format: 'AUDIOBOOK' })
    expect(result.errors).toBeUndefined()
    expect(result.data?.awardSections).toEqual([])
  })
})
