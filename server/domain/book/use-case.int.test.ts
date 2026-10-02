import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { CoverUrl as CoverUrlType, Isbn13 as Isbn13Type } from '~/domain/book/types'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/config', () => ({
  config: () => ({ googleApiKey: 'test-key', premiumUserIds: [] }),
}))

/** Queued Gemini answers, consumed in call order. An Error is thrown. */
let answers: unknown[] = []
mock.module('~/domain/scan/gemini', () => ({
  generate: async ({ step }: { step: string }) => {
    const value = answers.shift()
    if (value === undefined) throw new Error(`no queued answer for step "${step}"`)
    if (value instanceof Error) throw value
    return { value, usage: { promptTokens: 10, outputTokens: 5, thinkingTokens: 0, searches: 1 } }
  },
}))
/** The published covers by ISBN, and the stored covers that no longer load. */
const publishedCovers: Record<string, string> = {}
const goneCovers = new Set<string>()
const probed: string[] = []
mock.module('~/domain/scan/published-cover', () => ({
  publishedCoverOf: async (isbn13: string) => publishedCovers[isbn13],
  isCoverGone: async (url: string) => {
    probed.push(url)
    return goneCovers.has(url)
  },
}))

const { BookUseCase } = await import('~/domain/book/use-case')
const { BookCommand } = await import('~/domain/book/command')
const { BookId, CoverUrl, Isbn13, Synopsis } = await import('~/domain/book/primitives')
const { monthOf } = await import('~/domain/quota/business-rules')
const { AuthorName, BookTitle } = await import('~/domain/shared/primitives')

const reader = 'reader-1' as UserId
let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
  answers = []
  for (const isbn of Object.keys(publishedCovers)) delete publishedCovers[isbn]
  goneCovers.clear()
  probed.length = 0
})

const spent = () =>
  (fake.data('ai-quotas', `${reader}_${monthOf(new Date())}`) as { scans: number } | null)?.scans ??
  0

const aBook = (facts: { isbn13?: Isbn13Type; publishedCoverUrl?: CoverUrlType } = {}) =>
  BookCommand.add(reader, {
    title: BookTitle('Le Nom du vent'),
    authors: [AuthorName('Patrick Rothfuss')],
    synopsis: Synopsis('An old summary.'),
    status: 'reading',
    ...facts,
  })

describe('bringing a record up to date', () => {
  test('rewrites what describes the work, keeps what names it, and spends one scan', async () => {
    const book = await aBook()
    answers = [
      {
        title: 'The Name of the Wind',
        authors: ['Someone Else'],
        synopsis: 'A fresh summary.',
        genre: 'fantasy',
        subgenres: ['fantasy épique'],
        pageCount: 662,
      },
    ]

    const refreshed = await BookUseCase.refresh(reader, book.id, 'fr')

    expect(refreshed).toMatchObject({
      title: 'Le Nom du vent',
      authors: ['Patrick Rothfuss'],
      status: 'reading',
      synopsis: 'A fresh summary.',
      genre: 'fantasy',
      pageCount: 662,
    })
    expect(spent()).toBe(1)
  })

  test('keeps a fact the lookup did not find', async () => {
    const book = await aBook()
    answers = [{ title: 'Le Nom du vent', authors: [], subgenres: [] }]

    const refreshed = await BookUseCase.refresh(reader, book.id, 'fr')

    expect(refreshed).toMatchObject({ synopsis: 'An old summary.' })
  })

  test('leaves the record untouched and spends nothing when the model fails', async () => {
    const book = await aBook()
    answers = [new Error('model down')]

    const refreshed = await BookUseCase.refresh(reader, book.id, 'fr')

    expect(refreshed).toEqual({ failed: 'model down' })
    expect(fake.data('books', book.id)).toMatchObject({ synopsis: 'An old summary.' })
    expect(spent()).toBe(0)
  })

  test('finds the cover by the ISBN on the record when the lookup names none', async () => {
    const book = await aBook({ isbn13: Isbn13('9782352943556') })
    publishedCovers['9782352943556'] = 'https://m.media-amazon.com/images/P/2352943558.01.jpg'
    answers = [{ title: 'Le Nom du vent', authors: [], subgenres: [] }]

    const refreshed = await BookUseCase.refresh(reader, book.id, 'fr')

    expect(refreshed).toMatchObject({
      publishedCoverUrl: 'https://m.media-amazon.com/images/P/2352943558.01.jpg',
    })
  })

  test('drops a stored cover that no longer loads when no other is found', async () => {
    const dead = CoverUrl('https://covers.openlibrary.org/b/isbn/9782352943556-M.jpg?default=false')
    const book = await aBook({ publishedCoverUrl: dead })
    goneCovers.add(String(dead))
    answers = [{ title: 'Le Nom du vent', authors: [], subgenres: [] }]

    await BookUseCase.refresh(reader, book.id, 'fr')

    expect(fake.data('books', book.id)).not.toHaveProperty('publishedCoverUrl')
  })

  test('keeps a stored cover that still loads, or that could not be checked', async () => {
    const stored = CoverUrl(
      'https://covers.openlibrary.org/b/isbn/9782352943556-M.jpg?default=false',
    )
    const book = await aBook({ publishedCoverUrl: stored })
    answers = [{ title: 'Le Nom du vent', authors: [], subgenres: [] }]

    await BookUseCase.refresh(reader, book.id, 'fr')

    expect(probed).toEqual([String(stored)])
    expect(fake.data('books', book.id)).toMatchObject({ publishedCoverUrl: String(stored) })
  })

  test('answers not-found for a book the reader does not own, without calling the model', async () => {
    expect(await BookUseCase.refresh(reader, BookId('missing'), 'fr')).toBe('not-found')
    expect(spent()).toBe(0)
  })
})
