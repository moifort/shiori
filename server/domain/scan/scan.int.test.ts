import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/config', () => ({ config: () => ({ googleApiKey: 'test-key' }) }))

/** Queued Gemini answers, consumed in call order: vision, enrichment, catalogue.
 *  Nobody pays Google in a test — what is asserted is what the pipeline does
 *  with an answer, including the answers a model really produces. */
let answers: unknown[] = []
const calls: string[] = []
/** The text each step was prompted with, keyed by step. */
const prompts: Record<string, string> = {}
/** The author's page runs beside the saga's, so it answers apart from the queue,
 *  whose order it would otherwise race for. */
const authorCalls: string[] = []
let authorAnswer: unknown

mock.module('~/domain/scan/gemini', () => ({
  generate: async ({ step, parts }: { step: string; parts: { text?: string }[] }) => {
    prompts[step] = parts.map((part) => part.text ?? '').join('')
    if (step === 'author') {
      authorCalls.push(prompts[step])
      if (authorAnswer instanceof Error) throw authorAnswer
      return {
        value: authorAnswer,
        usage: { promptTokens: 7, outputTokens: 3, thinkingTokens: 0, searches: 1 },
      }
    }
    calls.push(step)
    const value = answers.shift()
    if (value === undefined) throw new Error(`no queued answer for step "${step}"`)
    if (value instanceof Error) throw value
    return { value, usage: { promptTokens: 10, outputTokens: 5, thinkingTokens: 20, searches: 0 } }
  },
}))

/** Covers found by ISBN, standing in for Open Library and Amazon. Undefined means none. */
let covers: Record<string, string> = {}
const coverLookups: string[] = []

mock.module('~/domain/scan/open-library', () => ({
  openLibraryCoverOf: async () => undefined,
  openLibraryCoverByTitle: async () => undefined,
}))
mock.module('~/domain/author/infrastructure/wikipedia', () => ({
  portraitOf: async () => undefined,
}))

mock.module('~/domain/scan/published-cover', () => ({
  publishedCoverOf: async (isbn13: string) => {
    coverLookups.push(isbn13)
    return covers[isbn13]
  },
}))

const { ScanCommand } = await import('~/domain/scan/command')
const { AuthorQuery } = await import('~/domain/author/query')
const { authorKeyOf } = await import('~/domain/author/primitives')
const { SeriesQuery } = await import('~/domain/series/query')
const { seriesKeyOf } = await import('~/domain/series/primitives')
const { BookTitle } = await import('~/domain/shared/primitives')

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
  genre: 'fantasy',
  subgenres: ['Roman Initiatique'],
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

const anAuthor = {
  name: 'Patrick Rothfuss',
  nationality: 'américaine',
  birthYear: 1973,
  biography: 'Auteur américain de fantasy, connu pour la Chronique du tueur de roi.',
  series: [
    { name: 'Chronique du tueur de roi', volumeCount: 3, firstVolumeTitle: 'Le Nom du vent' },
  ],
  books: [],
}

beforeEach(() => {
  resetFakeFirestore()
  answers = []
  calls.length = 0
  authorCalls.length = 0
  authorAnswer = anAuthor
  covers = {}
  coverLookups.length = 0
})

describe('scanning a cover', () => {
  test('reads it, enriches it, and catalogues its saga', async () => {
    answers = [aCover, anEnrichment, aCatalogue]

    const { result, cacheHit } = await ScanCommand.scanWithCache(image, 'fr')

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

    const { result } = await ScanCommand.scanWithCache(image, 'fr')

    expect(result.recognized).toBe(false)
    expect(calls).toEqual(['vision'])
  })

  // Caching a miss would make a better photo of the same scene return the same
  // nothing, with no way for the reader to recover.
  test('does not cache an unrecognized cover', async () => {
    answers = [{ recognized: false, title: '', authors: [] }]
    await ScanCommand.scanWithCache(image, 'fr')

    answers = [aCover, anEnrichment, aCatalogue]
    const { cacheHit } = await ScanCommand.scanWithCache(image, 'fr')

    expect(cacheHit).toBe(false)
  })
})

describe('looking a title up', () => {
  // A typed title skips the cover: one grounded call finds the book, the
  // catalogue follows when the saga is new, and nothing is cached.
  test('enriches the title and catalogues its saga without reading a cover', async () => {
    answers = [anEnrichment, aCatalogue]

    const { result } = await ScanCommand.lookUpTitle(BookTitle('le nom du vent'), 'fr')

    expect(String(result.title)).toBe('Le Nom du vent')
    expect(String(result.series?.name)).toBe('Chronique du tueur de roi')
    expect(calls).toEqual(['enrichment', 'catalogue'])
    expect(
      await SeriesQuery.byId(seriesKeyOf('Chronique du tueur de roi', 'Patrick Rothfuss', 'book')),
    ).not.toBeNull()
  })
})

describe('reading the format', () => {
  // Enrichment rebuilds the result from a web search that knows nothing of the
  // photo, so the format read off the cover has to survive it.
  test('carries the format seen on the cover through enrichment', async () => {
    answers = [{ ...aCover, format: 'manga' }, anEnrichment, aCatalogue]

    const { result } = await ScanCommand.scanWithCache(image, 'fr')

    expect(result.format).toBe('manga')
  })

  test('leaves the format absent when the model answers outside the list', async () => {
    answers = [{ ...aCover, format: 'novel' }, anEnrichment, aCatalogue]

    const { result } = await ScanCommand.scanWithCache(image, 'fr')

    expect(result.format).toBeUndefined()
    expect(String(result.title)).toBe('Le Nom du vent')
  })
})

describe('classifying the genre', () => {
  test('keeps the genre chosen from the list and the subgenres beside it', async () => {
    answers = [aCover, anEnrichment, aCatalogue]

    const { result } = await ScanCommand.scanWithCache(image, 'fr')

    expect(result.genre).toBe('fantasy')
    expect((result.subgenres ?? []).map(String)).toEqual(['Roman Initiatique'])
  })

  test('drops a genre outside the list without losing the book', async () => {
    answers = [aCover, { ...anEnrichment, genre: 'epic-fantasy' }, aCatalogue]

    const { result } = await ScanCommand.scanWithCache(image, 'fr')

    expect(result.genre).toBeUndefined()
    expect(String(result.title)).toBe('Le Nom du vent')
  })

  test('keeps three subgenres at most', async () => {
    const subgenres = ['Dark Fantasy', 'Roman Initiatique', 'Musique', 'Magie']
    answers = [aCover, { ...anEnrichment, subgenres }, aCatalogue]

    const { result } = await ScanCommand.scanWithCache(image, 'fr')

    expect((result.subgenres ?? []).map(String)).toEqual(subgenres.slice(0, 3))
  })
})

describe('naming the edition', () => {
  // A book has several editions in one language — the Folio pocket and the
  // Québec edition of the same translation — and only the one on the shelf has
  // the cover the reader recognizes.
  test('asks for the ISBN of the edition the cover names', async () => {
    answers = [{ ...aCover, publisher: 'folio', language: 'fr' }, anEnrichment, aCatalogue]

    await ScanCommand.scanWithCache(image, 'fr')

    expect(prompts.enrichment).toContain('éditeur « folio », en français')
    expect(prompts.enrichment).toContain("l'ISBN-13 de CETTE édition")
  })

  // A special edition's own cover is often a 3D shot of the object; the regular
  // edition is asked for only to borrow its flat cover.
  test('asks for the regular edition of a special one', async () => {
    answers = [aCover, anEnrichment, aCatalogue]

    await ScanCommand.scanWithCache(image, 'fr')

    expect(prompts.enrichment).toContain('regularEditionIsbn13')
    expect(prompts.enrichment).toContain('collector')
  })

  test('falls back to an edition in the reader language for a typed title', async () => {
    answers = [anEnrichment, aCatalogue]

    await ScanCommand.lookUpTitle(BookTitle('Le Nom du vent'), 'en')

    expect(prompts.enrichment).toContain('Édition : en anglais.')
  })

  // The subgenres are the edition's words, not the reader's: an English book
  // scanned from a French app is filed under English labels.
  test('asks for the subgenres in the language of the edition, not of the reader', async () => {
    answers = [{ ...aCover, language: 'en' }, anEnrichment, aCatalogue]

    await ScanCommand.scanWithCache(image, 'fr')

    expect(prompts.enrichment).toContain(
      '« jeunesse »), écrits en anglais, la langue de cette édition',
    )
    expect(prompts.enrichment).toContain('doivent être en français')
  })
})

describe('finding the cover', () => {
  const nameOfTheWindCover =
    'https://covers.openlibrary.org/b/isbn/9782352943556-M.jpg?default=false'

  test('carries the publisher cover found by ISBN', async () => {
    covers = { '9782352943556': nameOfTheWindCover }
    answers = [aCover, anEnrichment, aCatalogue]

    const { result } = await ScanCommand.scanWithCache(image, 'fr')

    expect(String(result.coverUrl)).toBe(nameOfTheWindCover)
  })

  // The app draws its placeholder for an absent cover, so none found is simply
  // a book without one — never a failed scan.
  test('leaves the cover absent when none is found', async () => {
    answers = [aCover, anEnrichment, aCatalogue]

    const { result } = await ScanCommand.scanWithCache(image, 'fr')

    expect(result.coverUrl).toBeUndefined()
    expect(String(result.title)).toBe('Le Nom du vent')
  })

  // Without an ISBN there is nothing to look up, and a model-invented ISBN has
  // already been dropped by its check digit — so it never reaches the lookup.
  test('does not look anything up without a valid ISBN', async () => {
    answers = [aCover, { ...anEnrichment, isbn13: '9780000000001' }, aCatalogue]

    await ScanCommand.scanWithCache(image, 'fr')

    expect(coverLookups).toEqual([])
  })

  // A collector edition is often filed with a 3D shot of the object rather than
  // its cover, and every source serves the same shot. The regular edition's
  // cover is the same artwork, drawn flat.
  test('draws a special edition with the cover of its regular edition', async () => {
    const regularCover = 'https://m.media-amazon.com/images/P/2070612759.01._SCLZZZZZZZ_.jpg'
    covers = { '9782352943556': nameOfTheWindCover, '9782070612758': regularCover }
    answers = [aCover, { ...anEnrichment, regularEditionIsbn13: '9782070612758' }, aCatalogue]

    const { result } = await ScanCommand.scanWithCache(image, 'fr')

    expect(String(result.coverUrl)).toBe(regularCover)
    expect(String(result.isbn13)).toBe('9782352943556')
    expect(coverLookups).toEqual(['9782070612758'])
  })

  test("keeps the special edition's own cover when the regular one has none", async () => {
    covers = { '9782352943556': nameOfTheWindCover }
    answers = [aCover, { ...anEnrichment, regularEditionIsbn13: '9782070612758' }, aCatalogue]

    const { result } = await ScanCommand.scanWithCache(image, 'fr')

    expect(String(result.coverUrl)).toBe(nameOfTheWindCover)
    expect(coverLookups).toEqual(['9782070612758', '9782352943556'])
  })

  test('looks up a regular edition once when the model names the same ISBN twice', async () => {
    covers = { '9782352943556': nameOfTheWindCover }
    answers = [aCover, { ...anEnrichment, regularEditionIsbn13: '9782352943556' }, aCatalogue]

    await ScanCommand.scanWithCache(image, 'fr')

    expect(coverLookups).toEqual(['9782352943556'])
  })

  test('draws a typed special edition with the cover of its regular edition', async () => {
    covers = { '9782070612758': nameOfTheWindCover }
    answers = [{ ...anEnrichment, regularEditionIsbn13: '9782070612758' }, aCatalogue]

    const { result } = await ScanCommand.lookUpTitle(BookTitle('Le Nom du vent'), 'fr')

    expect(String(result.coverUrl)).toBe(nameOfTheWindCover)
  })

  test('serves the cover from the cache without looking it up again', async () => {
    covers = { '9782352943556': nameOfTheWindCover }
    answers = [aCover, anEnrichment, aCatalogue]
    await ScanCommand.scanWithCache(image, 'fr')
    coverLookups.length = 0

    const { result } = await ScanCommand.scanWithCache(image, 'fr')

    expect(String(result.coverUrl)).toBe(nameOfTheWindCover)
    expect(coverLookups).toEqual([])
  })
})

describe('the cache', () => {
  test('serves a second scan of the same cover without calling the model', async () => {
    answers = [aCover, anEnrichment, aCatalogue]
    await ScanCommand.scanWithCache(image, 'fr')
    calls.length = 0

    const { result, cacheHit, usage } = await ScanCommand.scanWithCache(image, 'fr')

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
    await ScanCommand.scanWithCache(image, 'fr')

    answers = [aCover, { ...anEnrichment, synopsis: 'Kvothe tells his own legend.' }]
    const { result, cacheHit } = await ScanCommand.scanWithCache(image, 'en')

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

    const { result } = await ScanCommand.scanWithCache(image, 'fr')

    expect(result.isbn13).toBeUndefined()
    expect(String(result.title)).toBe('Le Nom du vent')
  })

  // An unknown page count comes back as 0 surprisingly often. Stored, it renders
  // as a real count of nothing.
  test('drops a zero page count and an impossible year', async () => {
    answers = [aCover, { ...anEnrichment, pageCount: 0, firstPublishedIn: 1200 }, aCatalogue]

    const { result } = await ScanCommand.scanWithCache(image, 'fr')

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

    await ScanCommand.scanWithCache(image, 'fr')

    const series = await SeriesQuery.byId(
      seriesKeyOf('Chronique du tueur de roi', 'Patrick Rothfuss', 'book'),
    )
    expect(series?.volumes).toHaveLength(3)
  })
})

describe('cataloguing a saga', () => {
  // The defect: a French edition scanned from a French app came back with the
  // English titles of its sequels. The edition read off the cover says which
  // titles the reader will look for, and the prompt names it.
  test('asks for the volume titles of the edition read off the cover', async () => {
    answers = [{ ...aCover, language: 'en' }, anEnrichment, aCatalogue]

    await ScanCommand.scanWithCache(image, 'fr')

    expect(prompts.catalogue).toContain('Édition : en anglais.')
    expect(prompts.catalogue).toContain('doivent être en français')
  })

  test('falls back to the reader language when the cover does not settle the edition', async () => {
    answers = [aCover, anEnrichment, aCatalogue]

    await ScanCommand.scanWithCache(image, 'fr')

    expect(prompts.catalogue).toContain('Édition : en français.')
  })

  // A recording trails its book: the saga heard is catalogued from what Audible
  // lists, and a volume out in print only stays out of it.
  test('catalogues the saga heard from the recordings of a cover read as an audiobook', async () => {
    answers = [{ ...aCover, format: 'audiobook' }, anEnrichment, aCatalogue]

    const { result } = await ScanCommand.scanWithCache(image, 'fr')

    expect(String(result.series?.id)).toBe('chronique-du-tueur-de-roi--patrick-rothfuss--audio')
    expect(prompts.catalogue).toContain('ENREGISTRÉS EN LIVRE AUDIO en français')
    expect(prompts.catalogue).toContain('audible.fr')
    expect(
      await SeriesQuery.byId(
        seriesKeyOf('Chronique du tueur de roi', 'Patrick Rothfuss', 'audiobook'),
      ),
    ).not.toBeNull()
  })

  test('skips the third call when the saga is already catalogued', async () => {
    answers = [aCover, anEnrichment, aCatalogue]
    await ScanCommand.scanWithCache(image, 'fr')

    const other = Buffer.from('another cover')
    answers = [aCover, { ...anEnrichment, volumeNumber: 2 }]
    calls.length = 0
    await ScanCommand.scanWithCache(other, 'fr')

    expect(calls).toEqual(['vision', 'enrichment'])
  })

  test('skips it entirely for a standalone book', async () => {
    answers = [aCover, { ...anEnrichment, seriesName: null, volumeNumber: null, volumeKind: null }]

    const { result } = await ScanCommand.scanWithCache(image, 'fr')

    expect(result.series).toBeUndefined()
    expect(calls).toEqual(['vision', 'enrichment'])
  })

  // The reader still gets their book. The saga is catalogued by the next scan
  // that touches it, which is a far better outcome than failing the scan.
  test('still returns the book when the catalogue call fails', async () => {
    answers = [aCover, anEnrichment, new Error('grounding is down')]

    const { result } = await ScanCommand.scanWithCache(image, 'fr')

    expect(String(result.title)).toBe('Le Nom du vent')
    expect(String(result.series?.name)).toBe('Chronique du tueur de roi')
  })

  // Storing an empty catalogue would mark the saga as known and stop any later
  // scan from trying again with better grounding.
  test('does not store an empty catalogue', async () => {
    answers = [aCover, anEnrichment, { ...aCatalogue, volumes: [] }]

    await ScanCommand.scanWithCache(image, 'fr')

    const series = await SeriesQuery.byId(
      seriesKeyOf('Chronique du tueur de roi', 'Patrick Rothfuss', 'book'),
    )
    expect(series).toBeNull()
  })
})

describe("cataloguing the author's page", () => {
  const rothfuss = authorKeyOf('Patrick Rothfuss')

  // The page the reader is likely to open next is built while they review the
  // book, so tapping the author does not wait on the model.
  test('builds it for an author nobody has opened yet, in the edition read off the cover', async () => {
    answers = [{ ...aCover, language: 'en' }, anEnrichment, aCatalogue]

    const { usage } = await ScanCommand.scanWithCache(image, 'fr')

    expect(authorCalls).toHaveLength(1)
    expect(prompts.author).toContain('Patrick Rothfuss')
    expect(prompts.author).toContain('Édition : en anglais.')
    expect((await AuthorQuery.byKey(rothfuss))?.biography).toBeDefined()
    expect(usage.author?.searches).toBe(1)
  })

  test('builds it for a typed title too', async () => {
    answers = [anEnrichment, aCatalogue]

    await ScanCommand.lookUpTitle(BookTitle('le nom du vent'), 'fr')

    expect(await AuthorQuery.byKey(rothfuss)).not.toBeNull()
  })

  test('skips the call once the author is catalogued', async () => {
    answers = [aCover, anEnrichment, aCatalogue]
    await ScanCommand.scanWithCache(image, 'fr')

    answers = [aCover, { ...anEnrichment, volumeNumber: 2 }]
    authorCalls.length = 0
    const { usage } = await ScanCommand.scanWithCache(Buffer.from('another cover'), 'fr')

    expect(authorCalls).toHaveLength(0)
    expect(usage.author).toBeUndefined()
  })

  // A standalone book has no saga page, but its author still has one.
  test('builds it for a book outside any saga', async () => {
    answers = [aCover, { ...anEnrichment, seriesName: null, volumeNumber: null, volumeKind: null }]

    await ScanCommand.scanWithCache(image, 'fr')

    expect(authorCalls).toHaveLength(1)
  })

  test('still returns the book, and its saga, when the author call fails', async () => {
    answers = [aCover, anEnrichment, aCatalogue]
    authorAnswer = new Error('grounding is down')

    const { result } = await ScanCommand.scanWithCache(image, 'fr')

    expect(String(result.title)).toBe('Le Nom du vent')
    expect(await AuthorQuery.byKey(rothfuss)).toBeNull()
    expect(
      await SeriesQuery.byId(seriesKeyOf('Chronique du tueur de roi', 'Patrick Rothfuss', 'book')),
    ).not.toBeNull()
  })
})
