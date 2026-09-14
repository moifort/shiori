import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/config', () => ({ config: () => ({ googleApiKey: 'test-key' }) }))

/** Queued Gemini answers, consumed in call order: vision, enrichment, catalogue.
 *  Nobody pays Google in a test — what is asserted is what the pipeline does
 *  with an answer, including the answers a model really produces. */
let answers: unknown[] = []
const calls: string[] = []

mock.module('~/domain/scan/gemini', () => ({
  generate: async ({ step }: { step: string }) => {
    calls.push(step)
    const value = answers.shift()
    if (value === undefined) throw new Error(`no queued answer for step "${step}"`)
    if (value instanceof Error) throw value
    return { value, usage: { promptTokens: 10, outputTokens: 5, thinkingTokens: 20 } }
  },
}))

const { Scan } = await import('~/domain/scan')
const { SeriesQuery } = await import('~/domain/series/query')
const { seriesKeyOf } = await import('~/domain/series/primitives')

const image = Buffer.from('a cover photo')

const aCover = {
  recognized: true,
  title: 'Le Nom du vent',
  authors: ['Patrick Rothfuss'],
  publisher: 'Bragelonne',
}

const anEnrichment = {
  title: 'Le Nom du vent',
  authors: ['Patrick Rothfuss'],
  seriesName: 'Chronique du tueur de roi',
  volumeNumber: 1,
  volumeKind: 'main',
  firstPublishedIn: 2007,
  genres: ['Fantasy'],
  pageCount: 662,
  isbn13: '9782352943556',
  synopsis: 'Kvothe raconte sa propre légende.',
}

const aCatalogue = {
  name: 'Chronique du tueur de roi',
  author: 'Patrick Rothfuss',
  description: 'Un musicien devenu légende raconte sa vie sur trois jours.',
  volumes: [
    { kind: 'main', number: 1, title: 'Le Nom du vent', publishedIn: 2007 },
    { kind: 'main', number: 2, title: 'La Peur du sage', publishedIn: 2011 },
    { kind: 'novella', number: null, title: "L'Éclair de silence", publishedIn: 2014 },
  ],
}

beforeEach(() => {
  resetFakeFirestore()
  answers = []
  calls.length = 0
})

describe('scanning a cover', () => {
  test('reads it, enriches it, and catalogues its saga', async () => {
    answers = [aCover, anEnrichment, aCatalogue]

    const { result, cacheHit } = await Scan.scanWithCache(image, 'fr')

    expect(cacheHit).toBe(false)
    expect(String(result.title)).toBe('Le Nom du vent')
    expect(String(result.isbn13)).toBe('9782352943556')
    expect(String(result.series?.name)).toBe('Chronique du tueur de roi')
    expect(calls).toEqual(['vision', 'enrichment', 'catalogue'])
  })

  // A photo of a table is an ordinary thing for a camera to capture. It must come
  // back as "nothing here" without paying for the two calls that follow.
  test('stops at the cover when there is no book to read', async () => {
    answers = [{ recognized: false, title: '', authors: [] }]

    const { result } = await Scan.scanWithCache(image, 'fr')

    expect(result.recognized).toBe(false)
    expect(calls).toEqual(['vision'])
  })

  // Caching a miss would make a better photo of the same scene return the same
  // nothing, with no way for the reader to recover.
  test('does not cache an unrecognized cover', async () => {
    answers = [{ recognized: false, title: '', authors: [] }]
    await Scan.scanWithCache(image, 'fr')

    answers = [aCover, anEnrichment, aCatalogue]
    const { cacheHit } = await Scan.scanWithCache(image, 'fr')

    expect(cacheHit).toBe(false)
  })
})

describe('the cache', () => {
  test('serves a second scan of the same cover without calling the model', async () => {
    answers = [aCover, anEnrichment, aCatalogue]
    await Scan.scanWithCache(image, 'fr')
    calls.length = 0

    const { result, cacheHit, usage } = await Scan.scanWithCache(image, 'fr')

    expect(cacheHit).toBe(true)
    expect(calls).toEqual([])
    // Nothing ran, so nothing is reported — the metrics must be able to tell
    // "did not run" from "was free".
    expect(usage).toEqual({})
    expect(String(result.title)).toBe('Le Nom du vent')
  })

  // The same cover scanned in two languages must not serve one language's
  // synopsis to the other.
  test('is keyed by language as well as image', async () => {
    answers = [aCover, anEnrichment, aCatalogue]
    await Scan.scanWithCache(image, 'fr')

    answers = [aCover, { ...anEnrichment, synopsis: 'Kvothe tells his own legend.' }]
    const { result, cacheHit } = await Scan.scanWithCache(image, 'en')

    expect(cacheHit).toBe(false)
    expect(String(result.synopsis)).toBe('Kvothe tells his own legend.')
  })
})

describe('surviving what the model invents', () => {
  // The whole reason the brands exist. A model asked for an ISBN returns
  // something ISBN-shaped whether or not it knows one, and a wrong ISBN poisons
  // every later lookup silently.
  test('drops a bad ISBN instead of storing it', async () => {
    answers = [aCover, { ...anEnrichment, isbn13: '9780000000001' }, aCatalogue]

    const { result } = await Scan.scanWithCache(image, 'fr')

    expect(result.isbn13).toBeUndefined()
    expect(String(result.title)).toBe('Le Nom du vent')
  })

  // An unknown page count comes back as 0 surprisingly often. Stored, it renders
  // as a real count of nothing.
  test('drops a zero page count and an impossible year', async () => {
    answers = [aCover, { ...anEnrichment, pageCount: 0, firstPublishedIn: 1200 }, aCatalogue]

    const { result } = await Scan.scanWithCache(image, 'fr')

    expect(result.pageCount).toBeUndefined()
    expect(result.firstPublishedIn).toBeUndefined()
  })

  test('keeps the catalogue when one volume in it is malformed', async () => {
    answers = [
      aCover,
      anEnrichment,
      {
        ...aCatalogue,
        volumes: [
          ...aCatalogue.volumes,
          { kind: 'nonsense', number: 4, title: 'Tome fantôme', publishedIn: 2030 },
        ],
      },
    ]

    await Scan.scanWithCache(image, 'fr')

    const series = await SeriesQuery.byId(
      seriesKeyOf('Chronique du tueur de roi', 'Patrick Rothfuss'),
    )
    expect(series?.volumes).toHaveLength(3)
  })
})

describe('cataloguing a saga', () => {
  test('skips the third call when the saga is already catalogued', async () => {
    answers = [aCover, anEnrichment, aCatalogue]
    await Scan.scanWithCache(image, 'fr')

    const other = Buffer.from('another cover')
    answers = [aCover, { ...anEnrichment, volumeNumber: 2 }]
    calls.length = 0
    await Scan.scanWithCache(other, 'fr')

    expect(calls).toEqual(['vision', 'enrichment'])
  })

  test('skips it entirely for a standalone book', async () => {
    answers = [aCover, { ...anEnrichment, seriesName: null, volumeNumber: null, volumeKind: null }]

    const { result } = await Scan.scanWithCache(image, 'fr')

    expect(result.series).toBeUndefined()
    expect(calls).toEqual(['vision', 'enrichment'])
  })

  // The reader still gets their book. The saga is catalogued by the next scan
  // that touches it, which is a far better outcome than failing the scan.
  test('still returns the book when the catalogue call fails', async () => {
    answers = [aCover, anEnrichment, new Error('grounding is down')]

    const { result } = await Scan.scanWithCache(image, 'fr')

    expect(String(result.title)).toBe('Le Nom du vent')
    expect(String(result.series?.name)).toBe('Chronique du tueur de roi')
  })

  // Storing an empty catalogue would mark the saga as known and stop any later
  // scan from trying again with better grounding.
  test('does not store an empty catalogue', async () => {
    answers = [aCover, anEnrichment, { ...aCatalogue, volumes: [] }]

    await Scan.scanWithCache(image, 'fr')

    const series = await SeriesQuery.byId(
      seriesKeyOf('Chronique du tueur de roi', 'Patrick Rothfuss'),
    )
    expect(series).toBeNull()
  })
})
