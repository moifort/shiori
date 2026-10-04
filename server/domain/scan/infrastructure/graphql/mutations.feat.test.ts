import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { graphql } from 'graphql'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
let premiumUserIds: string[] = []
mock.module('~/system/config', () => ({
  config: () => ({ googleApiKey: 'test-key', premiumUserIds }),
}))

let answers: unknown[] = []
let prompts: string[] = []
mock.module('~/domain/scan/gemini', () => ({
  generate: async ({ step, parts }: { step: string; parts: { text?: string }[] }) => {
    prompts.push(parts.map((part) => part.text ?? '').join(''))
    // The author's page a described book builds is covered by the scan's own
    // tests: here it finds nothing, and stays out of the queue.
    if (step === 'author')
      return {
        value: { series: [], books: [] },
        usage: { promptTokens: 7, outputTokens: 3, thinkingTokens: 0, searches: 1 },
      }
    const value = answers.shift()
    if (value === undefined) throw new Error(`no queued answer for step "${step}"`)
    if (value instanceof Error) throw value
    return { value, usage: { promptTokens: 10, outputTokens: 5, thinkingTokens: 0, searches: 0 } }
  },
}))

const { schema } = await import('~/domain/shared/graphql/schema')
const { monthOf } = await import('~/domain/quota/business-rules')

const userId = 'reader-1' as UserId
let fake: ReturnType<typeof resetFakeFirestore>

beforeEach(() => {
  fake = resetFakeFirestore()
  answers = []
  prompts = []
  premiumUserIds = []
})

const searchTitle = (title: string) =>
  graphql({
    schema,
    source: `mutation($title: BookTitle!) {
      searchTitle(title: $title) { title authors firstPublishedIn seriesName volume }
    }`,
    variableValues: { title },
    // No event: the language then falls back to the default rather than reading
    // a header off a request there is none of.
    contextValue: { event: undefined, userId },
  })

describe('searchTitle', () => {
  test('answers the books a typed title may mean', async () => {
    answers = [
      {
        candidates: [
          {
            title: 'Fondation',
            authors: ['Isaac Asimov'],
            firstPublishedIn: 1951,
            seriesName: 'Fondation',
            volumeNumber: 1,
          },
          { title: 'Fondation et Empire', authors: ['Isaac Asimov'] },
        ],
      },
    ]

    const result = await searchTitle('fondation')

    expect(result.errors).toBeUndefined()
    expect(result.data).toEqual({
      searchTitle: [
        {
          title: 'Fondation',
          authors: ['Isaac Asimov'],
          firstPublishedIn: 1951,
          seriesName: 'Fondation',
          volume: 1,
        },
        {
          title: 'Fondation et Empire',
          authors: ['Isaac Asimov'],
          firstPublishedIn: null,
          seriesName: null,
          volume: null,
        },
      ],
    })
  })

  test('is refused with QUOTA_EXHAUSTED once the allowance is used up', async () => {
    fake.seed('ai-quotas', `${userId}_${monthOf(new Date())}`, {
      userId,
      month: monthOf(new Date()),
      scans: 5,
    })

    const result = await searchTitle('Dune')

    expect(result.errors?.[0]?.extensions?.code).toBe('QUOTA_EXHAUSTED')
  })

  test('fails with SCAN_FAILED when the model errors', async () => {
    answers = [new Error('model unavailable')]

    const result = await searchTitle('Dune')

    expect(result.errors?.[0]?.extensions?.code).toBe('SCAN_FAILED')
  })
})

const detectBooks = () =>
  graphql({
    schema,
    source: `mutation($image: String!) {
      detectBooks(imageBase64: $image) {
        title authors volume owned box { x y width height }
      }
    }`,
    variableValues: { image: Buffer.from('a shelf').toString('base64') },
    contextValue: { event: undefined, userId },
  })

describe('detectBooks', () => {
  test('answers the books of the photo with their frames', async () => {
    premiumUserIds = [userId]
    answers = [
      { books: [{ box_2d: [100, 200, 900, 250], title: 'Dune', authors: ['Frank Herbert'] }] },
    ]

    const result = await detectBooks()

    expect(result.errors).toBeUndefined()
    expect(result.data).toEqual({
      detectBooks: [
        {
          title: 'Dune',
          authors: ['Frank Herbert'],
          volume: null,
          owned: false,
          box: { x: 0.2, y: 0.1, width: 0.05, height: 0.8 },
        },
      ],
    })
  })

  test('is refused to a free account with PREMIUM_REQUIRED', async () => {
    const result = await detectBooks()

    expect(result.errors?.[0]?.extensions?.code).toBe('PREMIUM_REQUIRED')
  })
})

describe('describeDetectedBook', () => {
  test('answers a record to review and spends one scan', async () => {
    answers = [{ title: 'Dune', authors: ['Frank Herbert'], subgenres: [] }]

    const result = await graphql({
      schema,
      source: `mutation($book: DetectedBookInput!) {
        describeDetectedBook(book: $book) { recognized title authors format }
      }`,
      variableValues: { book: { title: 'Dune', authors: ['Frank Herbert'], format: 'BOOK' } },
      contextValue: { event: undefined, userId },
    })

    expect(result.errors).toBeUndefined()
    expect(result.data).toEqual({
      describeDetectedBook: {
        recognized: true,
        title: 'Dune',
        authors: ['Frank Herbert'],
        format: 'BOOK',
      },
    })
    const month = fake.data('ai-quotas', `${userId}_${monthOf(new Date())}`) as { scans: number }
    expect(month.scans).toBe(1)
  })
})

describe('scanSeriesVolume', () => {
  const scanSeriesVolume = () =>
    graphql({
      schema,
      source: `mutation($volume: SeriesVolumeInput!) {
        scanSeriesVolume(volume: $volume) { recognized title series { id name volume kind } }
      }`,
      variableValues: {
        volume: {
          title: 'Sweet Tooth',
          authors: ['Jeff Lemire'],
          seriesId: 'sweet-tooth--jeff-lemire',
          seriesName: 'Sweet Tooth',
          volume: 2,
          kind: 'MAIN',
          language: 'FR',
          format: 'COMIC',
        },
      },
      contextValue: { event: undefined, userId },
    })

  test('tells the model which volume and which format it is looking for', async () => {
    answers = [{ title: 'Sweet Tooth', authors: ['Jeff Lemire'], subgenres: [] }]

    const result = await scanSeriesVolume()

    expect(result.errors).toBeUndefined()
    expect(prompts[0]).toContain('Série : « Sweet Tooth », tome 2.')
    expect(prompts[0]).toContain('Format : comic.')
  })

  test('keeps the answer filed at the volume asked for', async () => {
    // The model named another volume of the saga: the catalogue decides.
    answers = [
      {
        title: 'Sweet Tooth',
        authors: ['Jeff Lemire'],
        seriesName: 'Sweet Tooth',
        volumeNumber: 1,
        volumeKind: 'main',
        subgenres: [],
      },
    ]

    const result = await scanSeriesVolume()

    expect(result.data).toEqual({
      scanSeriesVolume: {
        recognized: true,
        title: 'Sweet Tooth',
        series: { id: 'sweet-tooth--jeff-lemire', name: 'Sweet Tooth', volume: 2, kind: 'MAIN' },
      },
    })
    const month = fake.data('ai-quotas', `${userId}_${monthOf(new Date())}`) as { scans: number }
    expect(month.scans).toBe(1)
  })
})

describe('scanSeriesVolume, with the volumes the reader holds', () => {
  const volumeOne = {
    id: 'sweet-tooth-1',
    userId,
    title: 'Sweet Tooth',
    authors: ['Jeff Lemire'],
    format: 'comic',
    media: ['print'],
    language: 'fr',
    publisher: 'Urban Comics',
    isbn13: '9782365777148',
    series: { id: 'sweet-tooth--jeff-lemire', name: 'Sweet Tooth', volume: 1, kind: 'main' },
    subgenres: [],
    narrators: [],
    status: 'read',
    hidden: false,
    addedAt: new Date('2026-01-02T08:00:00.000Z'),
    updatedAt: new Date('2026-01-02T08:00:00.000Z'),
  }

  const scanVolumeTwo = () =>
    graphql({
      schema,
      source: `mutation($volume: SeriesVolumeInput!) {
        scanSeriesVolume(volume: $volume) { isbn13 }
      }`,
      variableValues: {
        volume: {
          title: 'Sweet Tooth',
          authors: ['Jeff Lemire'],
          seriesId: 'sweet-tooth--jeff-lemire',
          seriesName: 'Sweet Tooth',
          volume: 2,
          kind: 'MAIN',
          language: 'FR',
          format: 'COMIC',
        },
      },
      contextValue: { event: undefined, userId },
    })

  test('names the other volumes, their ISBNs and their publisher', async () => {
    fake.seed('books', volumeOne.id, volumeOne)
    fake.seed('series', 'sweet-tooth--jeff-lemire~fr', {
      id: 'sweet-tooth--jeff-lemire',
      name: 'Sweet Tooth',
      author: 'Jeff Lemire',
      language: 'fr',
      volumes: [
        { number: 1, title: 'Sweet Tooth', kind: 'main' },
        { number: 2, title: 'Sweet Tooth', kind: 'main', releases: { fr: '2016-03-04' } },
      ],
    })
    answers = [{ title: 'Sweet Tooth', authors: ['Jeff Lemire'], subgenres: [] }]

    await scanVolumeTwo()

    expect(prompts[0]).toContain('9782365777148 (tome 1)')
    expect(prompts[0]).toContain('éditeur « Urban Comics »')
    expect(prompts[0]).toContain('2016-03-04')
  })

  test("drops another volume's ISBN rather than draw its cover", async () => {
    fake.seed('books', volumeOne.id, volumeOne)
    answers = [
      { title: 'Sweet Tooth', authors: ['Jeff Lemire'], isbn13: '9782365777148', subgenres: [] },
    ]

    const result = await scanVolumeTwo()

    expect(result.errors).toBeUndefined()
    expect(result.data).toEqual({ scanSeriesVolume: { isbn13: null } })
  })
})

describe('a scanned book the reader already keeps', () => {
  const scanTitle = () =>
    graphql({
      schema,
      source: `mutation($title: BookTitle!) {
        scanTitle(title: $title) { title ownedCopy { id title } }
      }`,
      variableValues: { title: 'dune' },
      contextValue: { event: undefined, userId },
    })

  const owned = {
    userId,
    title: 'Dune',
    authors: ['Frank Herbert'],
    format: 'book',
    subgenres: [],
    narrators: [],
    status: 'read',
    hidden: false,
    addedAt: new Date('2026-01-02T08:00:00.000Z'),
    updatedAt: new Date('2026-01-02T08:00:00.000Z'),
  }

  test('points at the copy on the shelf', async () => {
    fake.seed('books', 'dune-1', { ...owned, id: 'dune-1' })
    answers = [{ title: 'Dune', authors: ['Frank Herbert'], subgenres: [] }]

    const result = await scanTitle()

    expect(result.errors).toBeUndefined()
    expect(result.data).toEqual({
      scanTitle: { title: 'Dune', ownedCopy: { id: 'dune-1', title: 'Dune' } },
    })
  })

  test('points at nothing when only another reader keeps it', async () => {
    fake.seed('books', 'dune-2', { ...owned, id: 'dune-2', userId: 'reader-2' })
    answers = [{ title: 'Dune', authors: ['Frank Herbert'], subgenres: [] }]

    const result = await scanTitle()

    expect(result.errors).toBeUndefined()
    expect(result.data).toEqual({ scanTitle: { title: 'Dune', ownedCopy: null } })
  })
})
