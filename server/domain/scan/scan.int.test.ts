import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { ScanResult } from '~/domain/scan/types'
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
  openLibraryIsbnsOf: async () => [],
  openLibraryCoverOf: async () => undefined,
  openLibraryCoverByTitle: async () => undefined,
}))
mock.module('~/domain/author/infrastructure/wikipedia', () => ({
  portraitOf: async () => undefined,
}))
mock.module('~/domain/author/infrastructure/wikidata', () => ({
  wikidataPortraitOf: async () => undefined,
}))
mock.module('~/domain/author/infrastructure/open-library', () => ({
  openLibraryPortraitOf: async () => undefined,
}))

/** The editions the BnF lists, standing in for its catalogue; none by default,
 *  so a French edition goes to the grounded step as it always did. */
let bnfEditions: unknown[] = []
const bnfLookups: unknown[] = []
mock.module('~/domain/scan/bnf', () => ({
  bnfEditionsOf: async (book: unknown) => {
    bnfLookups.push(book)
    return bnfEditions
  },
}))

mock.module('~/domain/scan/published-cover', () => ({
  shelfCoverOf: async () => undefined,
  publishedCoverOf: async (isbn13: string) => {
    coverLookups.push(isbn13)
    return covers[isbn13]
  },
  isCoverGone: async () => false,
}))

const { ScanCommand } = await import('~/domain/scan/command')
const { AuthorQuery } = await import('~/domain/author/query')
const { authorKeyOf } = await import('~/domain/author/primitives')
const { SeriesQuery } = await import('~/domain/series/query')
const { seriesKeyOf } = await import('~/domain/series/primitives')
const { AuthorName, BookTitle } = await import('~/domain/shared/primitives')
const { Isbn13, Publisher, Synopsis } = await import('~/domain/book/primitives')
const { SeriesName, VolumeNumber } = await import('~/domain/series/primitives')

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
  bnfEditions = []
  bnfLookups.length = 0
})

describe('scanning a cover', () => {
  test('reads it and enriches it', async () => {
    answers = [aCover, anEnrichment]

    const { result, cacheHit } = await ScanCommand.scanWithCache(image, 'fr')

    expect(cacheHit).toBe(false)
    expect(String(result.title)).toBe('Le Nom du vent')
    expect(String(result.isbn13)).toBe('9782352943556')
    expect(String(result.series?.name)).toBe('Chronique du tueur de roi')
    expect(calls).toEqual(['vision', 'enrichment'])
  })

  // The review shows neither page, and a reader who never opens them never
  // pays for them: both are built on their first opening, as after an import
  // or a shelf photo. The 2026-10-22 scan waited 19 s on an author's page.
  test("leaves the saga's page and the author's to their first opening", async () => {
    answers = [aCover, anEnrichment]

    const { usage } = await ScanCommand.scanWithCache(image, 'fr')

    expect(authorCalls).toHaveLength(0)
    expect(Object.keys(usage)).toEqual(['vision', 'enrichment'])
    expect(
      await SeriesQuery.byId({
        saga: seriesKeyOf('Chronique du tueur de roi', 'Patrick Rothfuss', 'book'),
        language: 'fr',
      }),
    ).toBeNull()
    expect(await AuthorQuery.byKey(authorKeyOf('Patrick Rothfuss'))).toBeNull()
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

    answers = [aCover, anEnrichment]
    const { cacheHit } = await ScanCommand.scanWithCache(image, 'fr')

    expect(cacheHit).toBe(false)
  })
})

describe('looking a title up', () => {
  // A typed title skips the cover: one grounded call finds the book, and its
  // saga and author wait for their first opening, as a cover's do.
  test('enriches the title without reading a cover', async () => {
    answers = [anEnrichment]

    const { result } = await ScanCommand.lookUpTitle(BookTitle('le nom du vent'), 'fr')

    expect(String(result.title)).toBe('Le Nom du vent')
    expect(String(result.series?.name)).toBe('Chronique du tueur de roi')
    expect(calls).toEqual(['enrichment'])
    expect(authorCalls).toHaveLength(0)
  })

  // A picked candidate is asked as "title — author"; echoed back whole, the
  // author stayed in the title and a shelf photo no longer matched the book.
  test('asks the model for the title alone, by the author named beside it', async () => {
    answers = [anEnrichment, aCatalogue]

    await ScanCommand.lookUpTitle(BookTitle('Le Nom du vent — Patrick Rothfuss'), 'fr')

    expect(prompts.enrichment).toContain('Livre : « Le Nom du vent » de Patrick Rothfuss')
  })
})

describe('searching a typed title', () => {
  // The step before the lookup: which books the reader may mean. One quick
  // call, and nothing is built or catalogued until one of them is picked.
  test('lists the books the title may mean, most likely first', async () => {
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
          { title: 'Fondation et Empire', authors: ['Isaac Asimov'], firstPublishedIn: 1952 },
        ],
      },
    ]

    const { candidates } = await ScanCommand.findCandidates(BookTitle('fondation'), 'fr')

    expect(candidates.map((candidate) => String(candidate.title))).toEqual([
      'Fondation',
      'Fondation et Empire',
    ])
    expect(candidates[0]).toMatchObject({ seriesName: 'Fondation', volume: 1 })
    expect(candidates[1].seriesName).toBeUndefined()
    expect(calls).toEqual(['candidates'])
    expect(prompts.candidates).toContain('fondation')
  })

  test('lists an edition the model named twice only once', async () => {
    answers = [
      {
        candidates: [
          { title: 'Le Nom du vent', authors: ['Patrick Rothfuss'] },
          { title: 'Le nom du Vent', authors: ['patrick rothfuss'] },
        ],
      },
    ]

    const { candidates } = await ScanCommand.findCandidates(BookTitle('Le Nom du vent'), 'fr')

    expect(candidates).toHaveLength(1)
  })

  test('drops an entry without a title and keeps five at most', async () => {
    answers = [
      {
        candidates: [
          { title: '', authors: ['Nobody'] },
          ...['A', 'B', 'C', 'D', 'E', 'F'].map((letter) => ({
            title: `Tome ${letter}`,
            authors: ['Someone'],
          })),
        ],
      },
    ]

    const { candidates } = await ScanCommand.findCandidates(BookTitle('Tome A'), 'fr')

    expect(candidates.map((candidate) => String(candidate.title))).toEqual([
      'Tome A',
      'Tome B',
      'Tome C',
      'Tome D',
      'Tome E',
    ])
  })

  // The model does not search the web: a recent book is unknown to it, and
  // what the reader typed is then the only lead to the right one.
  test('offers the book as typed when the model knows none by that title', async () => {
    answers = [{ candidates: [{ title: 'Le mensonge', authors: ['Christopher Bouix'] }] }]

    const { candidates } = await ScanCommand.findCandidates(
      BookTitle('Le mensonge suffit - Christopher Bouix'),
      'fr',
    )

    expect(candidates.map(({ title, authors }) => ({ title, authors }))).toEqual([
      { title: BookTitle('Le mensonge suffit'), authors: [AuthorName('Christopher Bouix')] },
      { title: BookTitle('Le mensonge'), authors: [AuthorName('Christopher Bouix')] },
    ])
  })

  test('offers the book as typed alone when nothing matched', async () => {
    answers = [{ candidates: [] }]

    const { candidates } = await ScanCommand.findCandidates(BookTitle('Le mensonge suffit'), 'fr')

    expect(candidates).toEqual([{ title: BookTitle('Le mensonge suffit'), authors: [] }])
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

  test('takes the format the search filed the book under', async () => {
    answers = [
      { ...aCover, format: 'book' },
      { ...anEnrichment, subgenres: ['Space Opera', 'Bande Dessinée'] },
      aCatalogue,
    ]

    const { result } = await ScanCommand.scanWithCache(image, 'fr')

    expect(result.format).toBe('bande-dessinee')
    expect((result.subgenres ?? []).map(String)).toEqual(['Space Opera'])
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

  // The volumes of a comic are often all titled after the saga: without its
  // number, volume 2 was looked up as volume 1, ISBN and cover with it.
  test('names the volume and the format the cover printed', async () => {
    answers = [
      { ...aCover, format: 'comic', seriesName: 'Sweet Tooth', volumeNumber: 2 },
      anEnrichment,
      aCatalogue,
    ]

    await ScanCommand.scanWithCache(image, 'fr')

    expect(prompts.enrichment).toContain('Série : « Sweet Tooth », tome 2.')
    expect(prompts.enrichment).toContain('Format : comic.')
  })

  test('names neither for a plain standalone book', async () => {
    answers = [aCover, anEnrichment, aCatalogue]

    await ScanCommand.scanWithCache(image, 'fr')

    expect(prompts.enrichment).not.toContain('Série :')
    expect(prompts.enrichment).not.toContain('Format :')
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

describe('describing a named book from the BnF', () => {
  const named = {
    recognized: true,
    title: BookTitle('Le Nom du vent'),
    authors: [AuthorName('Patrick Rothfuss')],
    format: 'book',
    publisher: Publisher('Bragelonne'),
    language: 'fr',
    subgenres: [],
  } as ScanResult

  const bragelonne = {
    isbn13: '9782352942832',
    publisher: 'Bragelonne',
    year: '2009',
    pageCount: 648,
    summary: 'Un aubergiste raconte la véritable histoire de sa vie.',
  }
  const pocket = { isbn13: '9782811201104', publisher: 'Milady', year: '2010', pageCount: 832 }

  const aPick = {
    edition: 0,
    regularEdition: null,
    firstPublishedIn: 2007,
    genre: 'fantasy',
    subgenres: ['fantasy initiatique'],
    synopsis: 'Kvothe, devenu aubergiste, raconte sa propre légende.',
  }

  test('describes a French edition from the catalogue, with no web search', async () => {
    bnfEditions = [bragelonne, pocket]
    covers = { '9782352942832': 'https://example.com/nom-du-vent.jpg' }
    answers = [aPick]

    const { result, usage } = await ScanCommand.lookUpEdition(named, 'fr')

    expect(calls).toEqual(['enrichment-library'])
    expect(result).toMatchObject({
      title: 'Le Nom du vent',
      isbn13: '9782352942832',
      pageCount: 648,
      firstPublishedIn: 2007,
      genre: 'fantasy',
      synopsis: 'Kvothe, devenu aubergiste, raconte sa propre légende.',
      coverUrl: 'https://example.com/nom-du-vent.jpg',
    })
    expect(usage.enrichment?.searches).toBe(0)
    expect(prompts['enrichment-library']).toContain('[1] ISBN 9782811201104, éditeur Milady')
    expect(prompts['enrichment-library']).toContain(
      "résumé de l'éditeur, édition [0] : Un aubergiste raconte",
    )
  })

  test('files an album the catalogue calls a bande dessinée under that format', async () => {
    bnfEditions = [bragelonne]
    answers = [{ ...aPick, subgenres: ['space opera', 'bande dessinée'] }]

    const { result } = await ScanCommand.lookUpEdition(named, 'fr')

    expect(result.format).toBe('bande-dessinee')
    expect(result.subgenres).toEqual(['Space Opera'] as never)
  })

  test('spells whole the title and the publisher the spine misread', async () => {
    bnfEditions = [{ ...bragelonne, title: 'Le Nom du vent — Chronique du tueur de roi' }]
    answers = [aPick]

    const { result } = await ScanCommand.lookUpEdition(
      { ...named, title: BookTitle('Le N om du vent'), publisher: Publisher('Brag elonne') },
      'fr',
    )

    expect(result).toMatchObject({ title: 'Le Nom du vent', publisher: 'Bragelonne' })
  })

  test('looks the book up on the web when no edition is the one held', async () => {
    bnfEditions = [pocket]
    answers = [{ ...aPick, edition: null }, anEnrichment]

    const { result, usage } = await ScanCommand.lookUpEdition(named, 'fr')

    expect(calls).toEqual(['enrichment-library', 'enrichment'])
    expect(result.isbn13).toBe(Isbn13('9782352943556'))
    // Both calls are billed to the one lookup.
    expect(usage.enrichment?.promptTokens).toBe(20)
  })

  test('looks the book up on the web when it would be left without a synopsis', async () => {
    bnfEditions = [bragelonne]
    answers = [{ ...aPick, synopsis: null }, anEnrichment]

    const { result } = await ScanCommand.lookUpEdition(named, 'fr')

    expect(calls).toEqual(['enrichment-library', 'enrichment'])
    expect(result.synopsis).toBe(Synopsis('Kvothe raconte sa propre légende.'))
  })

  // A refresh keeps the synopsis a lookup did not find: no web search for it.
  test('keeps to the catalogue when the record already has a synopsis', async () => {
    bnfEditions = [bragelonne]
    answers = [{ ...aPick, synopsis: null }]

    const { result } = await ScanCommand.lookUpEdition(
      { ...named, synopsis: Synopsis('Le résumé déjà sur la fiche.') },
      'fr',
    )

    expect(calls).toEqual(['enrichment-library'])
    expect(result.synopsis).toBeUndefined()
    expect(result.isbn13).toBe(Isbn13('9782352942832'))
  })

  test('looks the book up on the web when the catalogue lists nothing', async () => {
    answers = [anEnrichment]

    await ScanCommand.lookUpEdition(named, 'fr')

    expect(calls).toEqual(['enrichment'])
  })

  test('looks the book up on the web when the model fails on the catalogue', async () => {
    bnfEditions = [bragelonne]
    answers = [new Error('Gemini returned no content'), anEnrichment]

    const { result } = await ScanCommand.lookUpEdition(named, 'fr')

    expect(calls).toEqual(['enrichment-library', 'enrichment'])
    expect(result.isbn13).toBe(Isbn13('9782352943556'))
  })

  test('never asks the BnF about an edition in another language', async () => {
    answers = [anEnrichment]

    await ScanCommand.lookUpEdition({ ...named, language: 'en' } as ScanResult, 'fr')

    expect(bnfLookups).toEqual([])
    expect(calls).toEqual(['enrichment'])
  })

  test('never asks the BnF about a recording', async () => {
    answers = [anEnrichment]

    await ScanCommand.lookUpEdition({ ...named, format: 'audiobook' } as ScanResult, 'fr')

    expect(bnfLookups).toEqual([])
  })

  // The catalogue numbers a manga's volumes; the reader's other volumes are
  // never this one, whatever the model would pick.
  test('shows only this volume, never one the reader holds as another', async () => {
    const volume = (isbn13: string, number: string) => ({
      isbn13,
      publisher: 'Glénat',
      volume: number,
    })
    bnfEditions = [
      volume('9782723434829', '5'),
      volume('9782723489928', '5'),
      volume('9782723428811', '4'),
    ]
    answers = [{ ...aPick, synopsis: 'Luffy affronte Kuro.' }]
    const onePiece = {
      ...named,
      title: BookTitle('One Piece'),
      authors: [AuthorName('Eiichirō Oda')],
      format: 'manga',
      series: {
        saga: seriesKeyOf('One Piece', 'Eiichirō Oda', 'manga'),
        name: SeriesName('One Piece'),
        volume: VolumeNumber(5),
        kind: 'main',
      },
    } as ScanResult

    await ScanCommand.lookUpEdition(onePiece, 'fr', {
      siblings: [{ volume: VolumeNumber(5), kind: 'main', isbn13: Isbn13('9782723489928') }],
    })

    expect(bnfLookups).toEqual([{ title: 'One Piece', author: 'Eiichirō Oda', volume: 5 }])
    expect(prompts['enrichment-library']).toContain('[0] ISBN 9782723434829')
    // The sibling is named only as what this volume is not.
    expect(prompts['enrichment-library']).not.toContain('[1]')
    expect(prompts['enrichment-library']).not.toContain('9782723428811')
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
})

describe('cataloguing a saga', () => {
  const kingkiller = seriesKeyOf('Chronique du tueur de roi', 'Patrick Rothfuss', 'book')
  const catalogued = (language: 'fr' | 'en' = 'fr', id = kingkiller) =>
    ScanCommand.catalogueSeries(
      id,
      SeriesName('Chronique du tueur de roi'),
      AuthorName('Patrick Rothfuss'),
      'fr',
      language,
    )

  // The defect: a French edition scanned from a French app came back with the
  // English titles of its sequels. The edition held says which titles the
  // reader will look for, and the prompt names it.
  test('asks for the volume titles of the edition held', async () => {
    answers = [aCatalogue]

    await catalogued('en')

    expect(prompts.catalogue).toContain('Édition : en anglais.')
    expect(prompts.catalogue).toContain('doivent être en français')
  })

  // A recording trails its book: the saga heard is catalogued from what Audible
  // lists, and a volume out in print only stays out of it.
  test('catalogues the saga heard from its recordings', async () => {
    answers = [aCatalogue]
    const id = seriesKeyOf('Chronique du tueur de roi', 'Patrick Rothfuss', 'audiobook')

    await catalogued('fr', id)

    expect(prompts.catalogue).toContain('ENREGISTRÉS EN LIVRE AUDIO en français')
    expect(prompts.catalogue).toContain('audible.fr')
    expect(await SeriesQuery.byId({ saga: id, language: 'fr' })).not.toBeNull()
  })

  // Each edition lists its own volumes: a saga catalogued in French says
  // nothing of what is out in English.
  test('keeps each edition its own catalogue', async () => {
    answers = [aCatalogue, { ...aCatalogue, name: 'The Kingkiller Chronicle' }]

    await catalogued('fr')
    await catalogued('en')

    expect(await SeriesQuery.byId({ saga: kingkiller, language: 'en' })).toMatchObject({
      name: 'The Kingkiller Chronicle',
      language: 'en',
    })
    expect(await SeriesQuery.byId({ saga: kingkiller, language: 'fr' })).toMatchObject({
      language: 'fr',
    })
  })

  test('keeps the catalogue when one volume in it is malformed', async () => {
    answers = [
      {
        ...aCatalogue,
        volumes: [
          ...aCatalogue.volumes,
          { kind: 'nonsense', number: 4, title: 'Tome fantôme', publishedIn: 2030 },
        ],
      },
    ]

    await catalogued()

    expect((await SeriesQuery.byId({ saga: kingkiller, language: 'fr' }))?.volumes).toHaveLength(3)
  })

  // A failed catalogue must not fail what asked for it: the saga is
  // catalogued by the next opening that touches it.
  test('answers nothing when the model call fails', async () => {
    answers = [new Error('grounding is down')]

    expect(await catalogued()).toEqual({})
    expect(await SeriesQuery.byId({ saga: kingkiller, language: 'fr' })).toBeNull()
  })

  // Storing an empty catalogue would mark the saga as known and stop any later
  // opening from trying again with better grounding.
  test('does not store an empty catalogue', async () => {
    answers = [{ ...aCatalogue, volumes: [] }]

    await catalogued()

    expect(await SeriesQuery.byId({ saga: kingkiller, language: 'fr' })).toBeNull()
  })
})
