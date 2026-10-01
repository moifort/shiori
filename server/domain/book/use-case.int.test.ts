import { beforeEach, describe, expect, mock, test } from 'bun:test'
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
mock.module('~/domain/scan/published-cover', () => ({ publishedCoverOf: async () => undefined }))

const { BookUseCase } = await import('~/domain/book/use-case')
const { BookCommand } = await import('~/domain/book/command')
const { BookId, Synopsis } = await import('~/domain/book/primitives')
const { monthOf } = await import('~/domain/quota/business-rules')
const { AuthorName, BookTitle } = await import('~/domain/shared/primitives')

const reader = 'reader-1' as UserId
let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
  answers = []
})

const spent = () =>
  (fake.data('ai-quotas', `${reader}_${monthOf(new Date())}`) as { scans: number } | null)?.scans ??
  0

const aBook = () =>
  BookCommand.add(reader, {
    title: BookTitle('Le Nom du vent'),
    authors: [AuthorName('Patrick Rothfuss')],
    synopsis: Synopsis('An old summary.'),
    status: 'reading',
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

  test('answers not-found for a book the reader does not own, without calling the model', async () => {
    expect(await BookUseCase.refresh(reader, BookId('missing'), 'fr')).toBe('not-found')
    expect(spent()).toBe(0)
  })
})
