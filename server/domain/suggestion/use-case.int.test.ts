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

/** Stands in for Open Library: a cover for every book but the ones it misses. */
let uncovered = new Set<string>()
mock.module('~/domain/suggestion/infrastructure/catalogue', () => ({
  coverOf: async (title: string) =>
    uncovered.has(title) ? undefined : `https://covers.example/${encodeURIComponent(title)}.jpg`,
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
  uncovered = new Set()
  shelve('shibumi', 'Shibumi', 'Trevanian', {
    rating: 5,
    favorite: true,
    publishedCoverUrl: 'https://covers.example/shibumi.jpg',
  })
  shelve('dune', 'Dune', 'Frank Herbert', { rating: 4 })
  answering(
    suggested('Dune', 'Frank Herbert'),
    suggested('La Sanction', 'Trevanian', ['Shibumi']),
    suggested('Silo', 'Hugh Howey', ['Dune']),
    suggested('Hypérion', 'Dan Simmons'),
    suggested('Ilium', 'Dan Simmons'),
    suggested('Seveneves', 'Neal Stephenson'),
    suggested('Expiration', 'Ted Chiang'),
  )
})

const look = (at: Date | string = october, language: 'fr' | 'en' = 'fr') =>
  SuggestionUseCase.monthly(reader, 'audiobook', language, true, new Date(at))
const read = (at: Date | string = october) =>
  SuggestionUseCase.monthly(reader, 'audiobook', 'fr', false, new Date(at))
const titles = (discoveries: { suggestions: { suggestion: { title: string } }[] }) =>
  discoveries.suggestions.map((view) => view.suggestion.title)

describe('the month’s discoveries', () => {
  test('the first look at Découvrir asks the model and shows its whole selection, held books left out', async () => {
    const discoveries = await look()

    expect(prompts).toHaveLength(1)
    expect(prompts[0]).toContain('« Shibumi » — Trevanian')
    expect(discoveries.month).toBe('2026-10')
    expect(titles(discoveries)).toEqual([
      'La Sanction',
      'Silo',
      'Hypérion',
      'Ilium',
      'Seveneves',
      'Expiration',
    ])
    const [sanction] = discoveries.suggestions
    expect(sanction?.references).toEqual([
      {
        bookId: 'shibumi',
        title: 'Shibumi',
        rank: { favorite: true, rating: 5, viaSeries: false },
        coverUrl: 'https://covers.example/shibumi.jpg',
      },
    ] as never)
    expect(sanction?.describedCoverUrl).toBe('https://covers.example/La%20Sanction.jpg' as never)
    expect(sanction?.awaitableFormats).toEqual(['book', 'audiobook'])
    expect(
      (fake.data('suggestion-queues', reader)?.suggestions as unknown[] | undefined)?.length,
    ).toBe(6)
  })

  test('a book Open Library misses is kept, without a cover', async () => {
    uncovered = new Set(['Le Cercle'])
    answering(suggested('Le Cercle', 'Bernard Minier'), suggested('Silo', 'Hugh Howey'))

    const discoveries = await look()

    expect(titles(discoveries)).toEqual(['Le Cercle', 'Silo'])
    expect(discoveries.suggestions[0]?.describedCoverUrl).toBeUndefined()
    expect(discoveries.suggestions[1]?.describedCoverUrl).toBe(
      'https://covers.example/Silo.jpg' as never,
    )
  })

  test('a look while another is making the selection says it is on its way', async () => {
    fake.seed('suggestion-queues', reader, {
      userId: reader,
      month: '',
      language: 'fr',
      generatedAt: new Date('2026-10-15T08:59:30Z'),
      generatingSince: new Date('2026-10-15T08:59:30Z'),
      suggestions: [],
    })
    const meanwhile = await look()

    expect(meanwhile.status).toBe('searching')
    expect(titles(meanwhile)).toEqual([])
    expect(prompts).toHaveLength(0)
  })

  test('the selection made is ready, and the mark of the search gone', async () => {
    const discoveries = await look()

    expect(discoveries.status).toBe('ready')
    expect(fake.data('suggestion-queues', reader)?.generatingSince).toBeUndefined()
  })

  test('the home page reads what there is and never asks', async () => {
    expect(titles(await read())).toEqual([])
    expect(prompts).toHaveLength(0)

    await look()
    startFakeRequest()
    const before = fake.queryReads
    expect(titles(await read('2026-10-20T09:00:00Z'))).toHaveLength(6)
    expect(prompts).toHaveLength(1)
    // The library, the sagas' opinions, the dismissals and the awaited editions
    // are four queries; the queue one get, the watches and descriptions getAlls.
    expect(fake.queryReads - before).toBe(4)
  })

  test('a dismissal lets the next one in and is told to the model next month', async () => {
    await look()
    expect(await SuggestionUseCase.dismiss(reader, 'silo--hugh-howey')).toMatchObject({
      key: 'silo--hugh-howey',
    })
    expect(titles(await look())).toEqual([
      'La Sanction',
      'Hypérion',
      'Ilium',
      'Seveneves',
      'Expiration',
    ])
    await look('2026-11-02T09:00:00Z')
    expect(prompts[1]).toContain('## Déjà proposés, pas intéressé\n- « Silo » — Hugh Howey')
  })

  test('a book added or awaited leaves the line', async () => {
    await look()
    startFakeRequest()
    shelve('sanction', 'La Sanction', 'Trevanian', { status: 'to-read' })
    fake.seed('awaited-editions', 'awaited-silo', {
      id: 'awaited-silo',
      userId: reader,
      watchKey: 'silo--hugh-howey--book--fr',
      format: 'book',
    })

    expect(titles(await look())).toEqual(['Hypérion', 'Ilium', 'Seveneves', 'Expiration'])
  })

  test('a month whose selection ran out stays empty until the next', async () => {
    await look()
    for (const key of [
      'sanction--trevanian',
      'silo--hugh-howey',
      'hyperion--dan-simmons',
      'ilium--dan-simmons',
      'seveneves--neal-stephenson',
      'expiration--ted-chiang',
    ])
      await SuggestionUseCase.dismiss(reader, key)

    const ranOut = await look('2026-10-28T09:00:00Z')
    expect(ranOut.status).toBe('ready')
    expect(titles(ranOut)).toEqual([])
    expect(prompts).toHaveLength(1)

    answering(suggested('Neuromancien', 'William Gibson'))
    expect(titles(await look('2026-11-03T09:00:00Z'))).toEqual(['Neuromancien'])
    expect(prompts).toHaveLength(2)
  })

  test('a new month is not shown before Découvrir asks for it', async () => {
    await look()
    expect(titles(await read('2026-11-01T09:00:00Z'))).toEqual([])
    expect(prompts).toHaveLength(1)
  })

  test('a reader who switched the app to English gets a selection written in English', async () => {
    await look()
    answering(suggested('Neuromancer', 'William Gibson'))
    const english = await look('2026-10-16T09:00:00Z', 'en')

    expect(prompts[1]).toContain('écrits en anglais')
    expect(titles(english)).toEqual(['Neuromancer'])
    expect(fake.data('suggestion-queues', reader)?.language).toBe('en')
  })

  test('a failed model leaves the line empty and is asked again the next day', async () => {
    await look()
    answer = new Error('Claude answered 529')
    const failed = await look('2026-11-01T09:00:00Z')
    expect(failed.status).toBe('none')
    expect(titles(failed)).toEqual([])
    expect(fake.data('suggestion-queues', reader)?.generatingSince).toBeUndefined()
    expect(titles(await look('2026-11-01T18:00:00Z'))).toEqual([])
    expect(prompts).toHaveLength(2)

    answering(suggested('Neuromancien', 'William Gibson'))
    expect(titles(await look('2026-11-02T09:00:00Z'))).toEqual(['Neuromancien'])
  })

  test('without a key, nothing is asked and the line is empty', async () => {
    configured = false
    expect(titles(await look())).toEqual([])
    expect(prompts).toHaveLength(0)
  })

  test('dismissing a suggestion the reader does not have is not-found', async () => {
    expect(await SuggestionUseCase.dismiss(reader, 'nothing')).toBe('not-found')
  })
})
