import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
let premiumUserIds: string[] = []
mock.module('~/system/config', () => ({
  config: () => ({ googleApiKey: 'test-key', premiumUserIds }),
}))

/** Queued Gemini answers, consumed in call order. An Error is thrown. */
let answers: unknown[] = []
const calls: string[] = []

mock.module('~/domain/scan/gemini', () => ({
  generate: async ({ step }: { step: string }) => {
    // The author's page runs beside the saga's and is covered by the scan's own
    // tests: here it finds nothing, and stays out of the queue it would race for.
    if (step === 'author')
      return {
        value: { series: [], books: [] },
        usage: { promptTokens: 7, outputTokens: 3, thinkingTokens: 0, searches: 1 },
      }
    calls.push(step)
    const value = answers.shift()
    if (value === undefined) throw new Error(`no queued answer for step "${step}"`)
    if (value instanceof Error) throw value
    return { value, usage: { promptTokens: 10, outputTokens: 5, thinkingTokens: 0, searches: 0 } }
  },
}))
mock.module('~/domain/scan/published-cover', () => ({
  publishedCoverOf: async () => undefined,
  isCoverGone: async () => false,
}))

/** What a shared page answers for its title. Undefined is a page with none. */
let pageTitle: string | undefined
mock.module('~/domain/scan/page-title', () => ({ pageTitleOf: async () => pageTitle }))

const { ScanUseCase } = await import('~/domain/scan/use-case')
const { monthOf } = await import('~/domain/quota/business-rules')
const { AuthorName, BookTitle } = await import('~/domain/shared/primitives')
const { BookCommand } = await import('~/domain/book/command')

const reader = 'reader-1' as UserId
const image = Buffer.from('a cover photo')
const aCover = { recognized: true, title: 'Le Nom du vent', authors: ['Patrick Rothfuss'] }
const anEnrichment = { title: 'Le Nom du vent', authors: ['Patrick Rothfuss'], subgenres: [] }

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
  answers = []
  calls.length = 0
  pageTitle = undefined
  premiumUserIds = []
})

const quotaDoc = () => `${reader}_${monthOf(new Date())}`
const spent = () => (fake.data('ai-quotas', quotaDoc()) as { scans: number } | null)?.scans ?? 0

describe('a metered scan', () => {
  test('spends one scan of the allowance once the model answered', async () => {
    answers = [aCover, anEnrichment]

    const outcome = await ScanUseCase.scanCover(reader, image, 'fr')

    expect(outcome).toMatchObject({ recognized: true, title: 'Le Nom du vent' })
    expect(spent()).toBe(1)
    expect(fake.data('ai-usage', monthOf(new Date()))).toMatchObject({ scans: 1 })
  })

  // The author's page is a catalogue like the saga's, and the admin screen
  // counts both on one line.
  test("counts the author's page with the catalogues", async () => {
    answers = [aCover, anEnrichment]

    await ScanUseCase.scanCover(reader, image, 'fr')

    expect(fake.data('ai-usage', monthOf(new Date()))).toMatchObject({
      catalogue: { promptTokens: 7, searches: 1 },
    })
  })

  test('spends nothing on a cover already scanned', async () => {
    answers = [aCover, anEnrichment]
    await ScanUseCase.scanCover(reader, image, 'fr')

    await ScanUseCase.scanCover(reader, image, 'fr')

    expect(spent()).toBe(1)
    expect(fake.data('ai-usage', monthOf(new Date()))).toMatchObject({ scans: 1, cacheHits: 1 })
  })

  test('refuses before calling the model once the allowance is used up', async () => {
    fake.seed('ai-quotas', quotaDoc(), { userId: reader, month: monthOf(new Date()), scans: 5 })

    expect(await ScanUseCase.lookUpTitle(reader, BookTitle('Dune'), 'fr')).toBe('quota-exhausted')
    expect(calls).toHaveLength(0)
  })

  test('says why the model failed, and spends nothing', async () => {
    answers = [new Error('model unavailable')]

    expect(await ScanUseCase.scanCover(reader, image, 'fr')).toEqual({
      failed: 'model unavailable',
    })
    expect(spent()).toBe(0)
  })
})

describe('a title search', () => {
  // Picking between the books a title may mean is free: the scan is the lookup
  // that follows.
  test('lists the candidates and spends nothing', async () => {
    answers = [{ candidates: [{ title: 'Dune', authors: ['Frank Herbert'] }] }]

    const outcome = await ScanUseCase.searchTitle(reader, BookTitle('dune'), 'fr')

    expect(outcome).toMatchObject([{ title: 'Dune', authors: ['Frank Herbert'] }])
    expect(spent()).toBe(0)
    expect(fake.data('ai-usage', monthOf(new Date()))).toMatchObject({
      scans: 0,
      enrichment: { promptTokens: 10 },
    })
  })

  test('refuses before calling the model once the allowance is used up', async () => {
    fake.seed('ai-quotas', quotaDoc(), { userId: reader, month: monthOf(new Date()), scans: 5 })

    expect(await ScanUseCase.searchTitle(reader, BookTitle('Dune'), 'fr')).toBe('quota-exhausted')
    expect(calls).toHaveLength(0)
  })

  test('says why the model failed', async () => {
    answers = [new Error('model unavailable')]

    expect(await ScanUseCase.searchTitle(reader, BookTitle('Dune'), 'fr')).toEqual({
      failed: 'model unavailable',
    })
  })
})

describe('a shared link', () => {
  test('costs nothing when the page has no title', async () => {
    const outcome = await ScanUseCase.lookUpLink(reader, 'https://example.com', 'fr')

    expect(outcome).toMatchObject({ recognized: false })
    expect(calls).toHaveLength(0)
    expect(spent()).toBe(0)
  })

  test('looks the page title up as a typed one', async () => {
    pageTitle = 'Le Nom du vent'
    answers = [anEnrichment]

    const outcome = await ScanUseCase.lookUpLink(reader, 'https://example.com', 'fr')

    expect(outcome).toMatchObject({ recognized: true, title: 'Le Nom du vent' })
    expect(calls).toEqual(['enrichment'])
    expect(spent()).toBe(1)
  })
})

describe('a shelf photo', () => {
  const shelf = {
    books: [
      { box_2d: [100, 500, 900, 560], title: 'Fondation', authors: ['Isaac Asimov'] },
      { box_2d: [120, 100, 880, 150], title: 'Dune', authors: ['Frank Herbert'], volumeNumber: 1 },
      { box_2d: [110, 300, 900, 340], title: null, authors: [] },
      { box_2d: [0, 0, 0, 0], title: 'Sans cadre', authors: [] },
    ],
  }

  test('answers each book in reading order, owned ones flagged, and spends nothing', async () => {
    premiumUserIds = [reader]
    await BookCommand.add(reader, {
      title: BookTitle('Fondation'),
      authors: [AuthorName('Isaac Asimov')],
    })
    answers = [shelf]

    const outcome = await ScanUseCase.detectBooks(reader, image, 'fr')

    expect(outcome).toMatchObject([
      { title: 'Dune', authors: ['Frank Herbert'], volume: 1, owned: false },
      { authors: [], owned: false, box: { x: 0.3, y: 0.11, width: 0.04, height: 0.79 } },
      { title: 'Fondation', owned: true },
    ])
    expect((outcome as unknown[])[1]).not.toHaveProperty('title')
    expect(calls).toEqual(['shelf'])
    expect(spent()).toBe(0)
    expect(fake.data('ai-usage', monthOf(new Date()))).toMatchObject({
      scans: 0,
      vision: { promptTokens: 10 },
    })
  })

  test('is refused to a free account before the model is called', async () => {
    expect(await ScanUseCase.detectBooks(reader, image, 'fr')).toBe('premium-required')
    expect(calls).toHaveLength(0)
  })

  test('is refused once the allowance is used up', async () => {
    premiumUserIds = [reader]
    fake.seed('ai-quotas', quotaDoc(), { userId: reader, month: monthOf(new Date()), scans: 100 })

    expect(await ScanUseCase.detectBooks(reader, image, 'fr')).toBe('quota-exhausted')
    expect(calls).toHaveLength(0)
  })

  test('keeps the thirty books read first', async () => {
    premiumUserIds = [reader]
    answers = [
      {
        books: Array.from({ length: 35 }, (_, index) => ({
          box_2d: [100, index * 28, 900, index * 28 + 20],
          title: `Livre ${index}`,
          authors: [],
        })),
      },
    ]

    const outcome = (await ScanUseCase.detectBooks(reader, image, 'fr')) as { title: string }[]

    expect(outcome).toHaveLength(30)
    expect(outcome[29].title).toBe('Livre 29')
  })

  test('says why the model failed', async () => {
    premiumUserIds = [reader]
    answers = [new Error('model unavailable')]

    expect(await ScanUseCase.detectBooks(reader, image, 'fr')).toEqual({
      failed: 'model unavailable',
    })
  })
})

describe('a book ticked on a shelf photo', () => {
  const ticked = {
    recognized: true,
    title: BookTitle('Le Nom du vent'),
    authors: [AuthorName('Patrick Rothfuss')],
    subgenres: [],
  }

  test('is enriched and its saga catalogued as a scanned cover is, for one scan', async () => {
    answers = [
      {
        ...anEnrichment,
        seriesName: 'Chronique du tueur de roi',
        volumeNumber: 1,
        volumeKind: 'main',
      },
      {
        name: 'Chronique du tueur de roi',
        author: 'Patrick Rothfuss',
        volumes: [{ kind: 'main', number: 1, title: 'Le Nom du vent' }],
      },
    ]

    const outcome = await ScanUseCase.describeDetected(reader, ticked, 'fr')

    expect(outcome).toMatchObject({
      recognized: true,
      title: 'Le Nom du vent',
      series: { name: 'Chronique du tueur de roi', volume: 1 },
    })
    expect(calls).toEqual(['enrichment', 'catalogue'])
    expect(spent()).toBe(1)
  })

  test('spends nothing when the model fails', async () => {
    answers = [new Error('model unavailable')]

    expect(await ScanUseCase.describeDetected(reader, ticked, 'fr')).toEqual({
      failed: 'model unavailable',
    })
    expect(spent()).toBe(0)
  })
})
