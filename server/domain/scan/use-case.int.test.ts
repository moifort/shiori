import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/config', () => ({
  config: () => ({ googleApiKey: 'test-key', premiumUserIds: [] }),
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
mock.module('~/domain/scan/published-cover', () => ({ publishedCoverOf: async () => undefined }))

/** What a shared page answers for its title. Undefined is a page with none. */
let pageTitle: string | undefined
mock.module('~/domain/scan/page-title', () => ({ pageTitleOf: async () => pageTitle }))

const { ScanUseCase } = await import('~/domain/scan/use-case')
const { monthOf } = await import('~/domain/quota/business-rules')
const { BookTitle } = await import('~/domain/shared/primitives')

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
