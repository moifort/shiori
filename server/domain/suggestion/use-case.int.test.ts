import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import {
  type FakeFirestore,
  fakeDb,
  resetFakeFirestore,
  startFakeRequest,
} from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

/** Stands in for Claude: what it answers, and every prompt it was sent. */
let configured = true
let answer: string | Error = '[]'
const prompts: string[] = []
mock.module('~/domain/suggestion/infrastructure/claude', () => ({
  isConfigured: () => configured,
  ask: async (prompt: string) => {
    prompts.push(prompt)
    if (answer instanceof Error) throw answer
    return answer
  },
}))

/** Stands in for Open Library and Google Books: the books neither knows. */
let unknown = new Set<string>()
mock.module('~/domain/suggestion/infrastructure/catalogue', () => ({
  catalogueEntryOf: async (title: string) =>
    unknown.has(title)
      ? { known: false }
      : { known: true, coverUrl: `https://covers.example/${encodeURIComponent(title)}.jpg` },
}))

const { SuggestionUseCase } = await import('~/domain/suggestion/use-case')

const reader = 'reader' as UserId
const october = new Date('2026-10-15T09:00:00Z')
let fake: FakeFirestore

const shelve = (id: string, title: string, author: string, extra: Record<string, unknown> = {}) =>
  fake.seed('books', id, {
    id,
    userId: reader,
    title,
    authors: [author],
    format: 'audiobook',
    media: [],
    genre: 'science-fiction',
    subgenres: [],
    narrators: [],
    language: 'fr',
    status: 'read',
    hidden: false,
    addedAt: new Date('2026-01-01'),
    ...extra,
  })

const suggested = (title: string, author: string, references: string[] = []) => ({
  title,
  originalTitle: title,
  author,
  language: 'en',
  kind: 'novel',
  reason: `Pour ${title}.`,
  short: `comme ${references[0] ?? 'rien'}`,
  references,
})

const answering = (...items: ReturnType<typeof suggested>[]) => {
  answer = JSON.stringify(items)
}

beforeEach(() => {
  fake = resetFakeFirestore()
  configured = true
  prompts.length = 0
  unknown = new Set(['Les Possédés d’Illiers'])
  shelve('shibumi', 'Shibumi', 'Trevanian', { rating: 5, favorite: true })
  shelve('dune', 'Dune', 'Frank Herbert', { rating: 4 })
  answering(
    suggested('Dune', 'Frank Herbert'),
    suggested('La Sanction', 'Trevanian', ['Shibumi']),
    suggested('Les Possédés d’Illiers', 'Jean-Claude Izzo'),
    suggested('Silo', 'Hugh Howey', ['Dune']),
    suggested('Hypérion', 'Dan Simmons'),
    suggested('Ilium', 'Dan Simmons'),
  )
})

describe('the month’s discoveries', () => {
  test('the first look asks the model and shows three, held and invented books left out', async () => {
    const discoveries = await SuggestionUseCase.monthly(reader, 'audiobook', 'fr', october)

    expect(prompts).toHaveLength(1)
    expect(prompts[0]).toContain('« Shibumi » — Trevanian')
    expect(discoveries.month).toBe('2026-10')
    expect(discoveries.suggestions.map((view) => view.suggestion.title)).toEqual([
      'La Sanction',
      'Silo',
      'Hypérion',
    ] as never)
    const [sanction] = discoveries.suggestions
    expect(sanction?.references).toEqual([
      {
        bookId: 'shibumi',
        title: 'Shibumi',
        rank: { favorite: true, rating: 5, viaSeries: false },
      },
    ] as never)
    expect(sanction?.describedCoverUrl).toBe('https://covers.example/La%20Sanction.jpg' as never)
    expect(sanction?.awaitableFormats).toEqual(['book', 'audiobook'])
    expect(
      (fake.data('suggestion-queues', reader)?.suggestions as unknown[] | undefined)?.length,
    ).toBe(4)
  })

  test('a second look the same day reads the stored selection without asking', async () => {
    await SuggestionUseCase.monthly(reader, 'audiobook', 'fr', october)
    startFakeRequest()
    const before = { doc: fake.docReads, query: fake.queryReads }
    const again = await SuggestionUseCase.monthly(
      reader,
      'audiobook',
      'fr',
      new Date('2026-10-15T18:00:00Z'),
    )

    expect(prompts).toHaveLength(1)
    expect(again.suggestions).toHaveLength(3)
    // The library, the sagas' opinions, the dismissals and the awaited editions
    // are four queries; the queue one get, the watches and descriptions getAlls.
    expect(fake.queryReads - before.query).toBe(4)
  })

  test('a dismissal lets the next one in and is told to the model next time', async () => {
    await SuggestionUseCase.monthly(reader, 'audiobook', 'fr', october)
    expect(await SuggestionUseCase.dismiss(reader, 'silo--hugh-howey')).toMatchObject({
      key: 'silo--hugh-howey',
    })
    const after = await SuggestionUseCase.monthly(reader, 'audiobook', 'fr', october)

    expect(after.suggestions.map((view) => view.suggestion.title)).toEqual([
      'La Sanction',
      'Hypérion',
      'Ilium',
    ] as never)
    await SuggestionUseCase.monthly(reader, 'audiobook', 'fr', new Date('2026-11-02T09:00:00Z'))
    expect(prompts[1]).toContain('## Déjà proposés, pas intéressé\n- « Silo » — Hugh Howey')
  })

  test('a book added or awaited leaves the line', async () => {
    await SuggestionUseCase.monthly(reader, 'audiobook', 'fr', october)
    startFakeRequest()
    shelve('sanction', 'La Sanction', 'Trevanian', { status: 'to-read' })
    fake.seed('awaited-editions', 'awaited-silo', {
      id: 'awaited-silo',
      userId: reader,
      watchKey: 'silo--hugh-howey--book--fr',
      format: 'book',
    })
    const after = await SuggestionUseCase.monthly(reader, 'audiobook', 'fr', october)

    expect(after.suggestions.map((view) => view.suggestion.title)).toEqual([
      'Hypérion',
      'Ilium',
    ] as never)
  })

  test('within the month, too few left asks again the next day, keeping what is left first', async () => {
    await SuggestionUseCase.monthly(reader, 'audiobook', 'fr', october)
    for (const key of ['silo--hugh-howey', 'hyperion--dan-simmons'])
      await SuggestionUseCase.dismiss(reader, key)
    answering(suggested('Seveneves', 'Neal Stephenson'), suggested('Ilium', 'Dan Simmons'))
    const sameDay = await SuggestionUseCase.monthly(reader, 'audiobook', 'fr', october)
    expect(sameDay.suggestions).toHaveLength(2)

    const nextDay = await SuggestionUseCase.monthly(
      reader,
      'audiobook',
      'fr',
      new Date('2026-10-16T09:00:00Z'),
    )
    expect(prompts).toHaveLength(2)
    expect(nextDay.suggestions.map((view) => view.suggestion.title)).toEqual([
      'La Sanction',
      'Ilium',
      'Seveneves',
    ] as never)
  })

  test('a new month starts afresh', async () => {
    await SuggestionUseCase.monthly(reader, 'audiobook', 'fr', october)
    answering(suggested('Seveneves', 'Neal Stephenson'))
    const november = await SuggestionUseCase.monthly(
      reader,
      'audiobook',
      'fr',
      new Date('2026-11-01T09:00:00Z'),
    )

    expect(november.month).toBe('2026-11')
    expect(november.suggestions.map((view) => view.suggestion.title)).toEqual([
      'Seveneves',
    ] as never)
  })

  test('a failed model keeps the selection there was', async () => {
    await SuggestionUseCase.monthly(reader, 'audiobook', 'fr', october)
    answer = new Error('Claude answered 529')
    const november = await SuggestionUseCase.monthly(
      reader,
      'audiobook',
      'fr',
      new Date('2026-11-01T09:00:00Z'),
    )

    expect(november.suggestions).toHaveLength(3)
  })

  test('without a key, nothing is asked and the line is empty', async () => {
    configured = false
    const discoveries = await SuggestionUseCase.monthly(reader, 'audiobook', 'fr', october)

    expect(discoveries.suggestions).toEqual([])
    expect(prompts).toHaveLength(0)
  })

  test('dismissing a suggestion the reader does not have is not-found', async () => {
    expect(await SuggestionUseCase.dismiss(reader, 'nothing')).toBe('not-found')
  })
})
