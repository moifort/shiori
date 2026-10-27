import { afterEach, beforeEach, describe, expect, mock, spyOn, test } from 'bun:test'
import { graphql } from 'graphql'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/domain/scan/bnf', () => ({ bnfEditionsOf: async () => [] }))
mock.module('~/system/object-store', () => ({
  objectStore: () => ({ downloadUrl: async () => 'https://fake.store/cover' }),
}))
/** The narrators the model was asked about, in order. */
const modelCalls: string[] = []
/** What the model says of the narrator; `fails` makes it throw. */
let modelAnswer: Record<string, unknown> | 'fails' = {
  name: 'Bernard Gabay',
  nationality: 'Français',
  birthYear: 1960,
  deathYear: null,
  biography: 'Comédien, voix française de Robert Downey Jr.',
  wikipediaTitle: 'Bernard_Gabay',
}
mock.module('~/domain/scan/gemini', () => ({
  generate: async ({ step, parts }: { step: string; parts: { text: string }[] }) => {
    if (step !== 'narrator') throw new Error(`no model call expected, got "${step}"`)
    modelCalls.push(parts[0]?.text.match(/Narrateur : (.+)/)?.[1] ?? '')
    if (modelAnswer === 'fails') throw new Error('model down')
    return { value: modelAnswer, usage: undefined }
  },
}))
mock.module('~/domain/scan/open-library', () => ({
  openLibraryIsbnsOf: async () => [],
  openLibraryCoverOf: async () => undefined,
  openLibraryCoverByTitle: async () => undefined,
}))
/** The names Wikipedia was asked about, in order, with the page the model named. */
const portraitSearches: string[] = []
let wikipediaHasFace = true
mock.module('~/domain/author/infrastructure/wikipedia', () => ({
  portraitOf: async (name: string, pageTitle?: string) => {
    portraitSearches.push(pageTitle ? `${name} (${pageTitle})` : name)
    return wikipediaHasFace ? 'https://upload.wikimedia.org/gabay.jpg' : undefined
  },
}))

const { schema } = await import('~/domain/shared/graphql/schema')

const userId = 'reader-1' as UserId
beforeEach(() => {
  resetFakeFirestore()
  portraitSearches.length = 0
  wikipediaHasFace = true
  modelCalls.length = 0
  modelAnswer = {
    name: 'Bernard Gabay',
    nationality: 'Français',
    birthYear: 1960,
    deathYear: null,
    biography: 'Comédien, voix française de Robert Downey Jr.',
    wikipediaTitle: 'Bernard_Gabay',
  }
})

const execute = (source: string) => graphql({ schema, source, contextValue: { event: {}, userId } })

const addBook = async (fields: string) => {
  const result = await execute(`mutation { addBook(input: { ${fields} }) { id } }`)
  expect(result.errors).toBeUndefined()
  return (result.data as { addBook: { id: string } }).addBook.id
}

type Page = {
  narrator: {
    key: string
    name: string
    portraitUrl: string | null
    favorite: boolean
    bookCount: number
    readCount: number
    seriesCount: number
    averageRating: number | null
  }
  catalogue: {
    nationality: string | null
    birthYear: number | null
    deathYear: number | null
    biography: string | null
  } | null
  awaitingCatalogue: boolean
  sagas: { id: string; name: string }[]
  books: { title: string }[]
}

const narratorPage = async (args: string) => {
  const result = await execute(
    `{ narratorPage(${args}) {
      narrator { key name portraitUrl favorite bookCount readCount seriesCount averageRating }
      catalogue { nationality birthYear deathYear biography }
      awaitingCatalogue
      sagas { id name }
      books { title }
    } }`,
  )
  expect(result.errors).toBeUndefined()
  return (result.data as { narratorPage: Page | null }).narratorPage
}

describe('a narrator’s page', () => {
  test('draws the recordings in their voice, by saga, with their face', async () => {
    for (const volume of [1, 2])
      await addBook(
        `title: "Dune ${volume}", authors: ["Frank Herbert"], format: AUDIOBOOK,
         narrators: ["Bernard Gabay"], status: ${volume === 1 ? 'READ' : 'TO_READ'},
         series: { id: "dune--frank-herbert--audio", name: "Dune", volume: ${volume}, kind: MAIN }`,
      )
    const loved = await addBook(
      'title: "L’Étranger", authors: ["Albert Camus"], format: AUDIOBOOK, narrators: ["Bernard Gabay"]',
    )
    await execute(`mutation { rateBook(id: "${loved}", rating: 4) { id } }`)
    // Read on paper: no narrator, whatever a stale field says.
    await addBook('title: "La Peste", authors: ["Albert Camus"]')
    await addBook(
      'title: "Fondation", authors: ["Isaac Asimov"], format: AUDIOBOOK, narrators: ["Someone Else"]',
    )

    const page = await narratorPage('key: "bernard-gabay"')

    expect(page?.narrator).toEqual({
      key: 'bernard-gabay',
      name: 'Bernard Gabay',
      portraitUrl: 'https://upload.wikimedia.org/gabay.jpg',
      favorite: false,
      bookCount: 3,
      // Dune 1, and L’Étranger, which its stars mark as listened to.
      readCount: 2,
      seriesCount: 1,
      averageRating: 4,
    })
    expect(page?.sagas.map((saga) => saga.name)).toEqual(['Dune'])
    expect(page?.books.map((book) => book.title)).toEqual(['L’Étranger'])
  })

  test('is described by the model on the first opening, then read for everyone', async () => {
    await addBook(
      'title: "Dune", authors: ["Frank Herbert"], format: AUDIOBOOK, narrators: ["Bernard Gabay"]',
    )
    const first = await narratorPage('key: "bernard-gabay"')
    await narratorPage('key: "bernard-gabay"')

    expect(first?.catalogue).toEqual({
      nationality: 'Français',
      birthYear: 1960,
      deathYear: null,
      biography: 'Comédien, voix française de Robert Downey Jr.',
    })
    expect(first?.awaitingCatalogue).toBe(false)
    expect(modelCalls).toEqual(['Bernard Gabay'])
    // On the page the model named.
    expect(portraitSearches).toEqual(['Bernard Gabay (Bernard_Gabay)'])
  })

  test('answers at once without waiting for the model, which the next ask builds', async () => {
    await addBook(
      'title: "Dune", authors: ["Frank Herbert"], format: AUDIOBOOK, narrators: ["Bernard Gabay"]',
    )
    const quick = await narratorPage('key: "bernard-gabay", waitForCatalogue: false')
    expect(quick?.awaitingCatalogue).toBe(true)
    expect(quick?.catalogue).toBeNull()
    expect(quick?.books.map((book) => book.title)).toEqual(['Dune'])
    expect(modelCalls).toEqual([])

    const built = await narratorPage('key: "bernard-gabay"')
    expect(built?.catalogue?.biography).toBe('Comédien, voix française de Robert Downey Jr.')
    expect(
      (await narratorPage('key: "bernard-gabay", waitForCatalogue: false'))?.awaitingCatalogue,
    ).toBe(false)
  })

  test('remembers a narrator the model knows nothing of, with the face Wikipedia gives', async () => {
    modelAnswer = { name: 'Bernard Gabay', biography: null, wikipediaTitle: null }
    await addBook(
      'title: "Dune", authors: ["Frank Herbert"], format: AUDIOBOOK, narrators: ["Bernard Gabay"]',
    )
    const page = await narratorPage('key: "bernard-gabay"')
    expect(page?.catalogue).toBeNull()
    expect(page?.narrator.portraitUrl).toBe('https://upload.wikimedia.org/gabay.jpg')
    expect(
      (await narratorPage('key: "bernard-gabay", waitForCatalogue: false'))?.awaitingCatalogue,
    ).toBe(false)
    expect(modelCalls).toEqual(['Bernard Gabay'])
  })

  test('still draws the recordings when the model fails, and does not ask again at once', async () => {
    modelAnswer = 'fails'
    wikipediaHasFace = false
    await addBook(
      'title: "Dune", authors: ["Frank Herbert"], format: AUDIOBOOK, narrators: ["Bernard Gabay"]',
    )
    const page = await narratorPage('key: "bernard-gabay"')
    expect(page?.books.map((book) => book.title)).toEqual(['Dune'])
    expect(page?.catalogue).toBeNull()
    expect(page?.narrator.portraitUrl).toBeNull()
    await narratorPage('key: "bernard-gabay"')
    expect(modelCalls).toEqual(['Bernard Gabay'])
    expect(portraitSearches).toEqual(['Bernard Gabay'])
  })

  test('is null for a narrator the reader holds nothing of, unless offered', async () => {
    expect(await narratorPage('key: "bernard-gabay"')).toBeNull()
    expect(await narratorPage('key: "bernard-gabay", offered: "Someone Else"')).toBeNull()
    const offered = await narratorPage('key: "bernard-gabay", offered: "Bernard Gabay"')
    expect(offered?.narrator.bookCount).toBe(0)
    expect(offered?.narrator.name).toBe('Bernard Gabay')
  })

  test('keeps the reader’s heart', async () => {
    await addBook(
      'title: "Dune", authors: ["Frank Herbert"], format: AUDIOBOOK, narrators: ["Bernard Gabay"]',
    )
    const hearted = await execute(
      'mutation { setNarratorFavorite(key: "bernard-gabay", favorite: true) }',
    )
    expect(hearted.data).toEqual({ setNarratorFavorite: true })
    expect((await narratorPage('key: "bernard-gabay"'))?.narrator.favorite).toBe(true)
    await execute('mutation { setNarratorFavorite(key: "bernard-gabay", favorite: false) }')
    expect((await narratorPage('key: "bernard-gabay"'))?.narrator.favorite).toBe(false)
  })
})

describe('a book', () => {
  test('names the key of each narrator, for their page', async () => {
    const id = await addBook(
      'title: "Dune", authors: ["Frank Herbert"], format: AUDIOBOOK, narrators: ["Frédéric Kneip", "Bernard Gabay"]',
    )
    const result = await execute(`{ book(id: "${id}") { narratorKeys } }`)
    expect(result.data).toEqual({ book: { narratorKeys: ['frederic-kneip', 'bernard-gabay'] } })
  })
})

describe('correcting a narrator', () => {
  // A pasted address is checked to serve an image: a page does not.
  beforeEach(() => {
    spyOn(globalThis, 'fetch').mockImplementation(
      (async (url: string) =>
        new Response(null, {
          headers: url.includes('/page')
            ? { 'content-type': 'text/html' }
            : { 'content-type': 'image/jpeg', 'content-length': '250000' },
        })) as unknown as typeof fetch,
    )
  })
  afterEach(() => {
    ;(globalThis.fetch as unknown as { mockRestore?: () => void }).mockRestore?.()
  })

  const gabay =
    'title: "Dune", authors: ["Frank Herbert"], format: AUDIOBOOK, narrators: ["Bernard Gabay"]'

  const correct = (fields: string) =>
    execute(`mutation { correctNarrator(key: "bernard-gabay", ${fields}) {
      narrator { portraitUrl }
      catalogue { nationality birthYear deathYear biography }
    } }`)

  test('writes the fields passed, clears those passed as null, and answers the page', async () => {
    await addBook(gabay)
    await narratorPage('key: "bernard-gabay"')

    const result = await correct(
      'biography: "Voix de Dune.", nationality: null, birthYear: 1958, portraitUrl: "https://example.com/gabay.jpg"',
    )

    expect(result.errors).toBeUndefined()
    expect(result.data).toEqual({
      correctNarrator: {
        narrator: { portraitUrl: 'https://example.com/gabay.jpg' },
        catalogue: {
          nationality: null,
          birthYear: 1958,
          deathYear: null,
          biography: 'Voix de Dune.',
        },
      },
    })
  })

  test('describes a narrator nobody had, with no model call then or later', async () => {
    await addBook(gabay)
    await correct('biography: "Voix de Dune."')
    const page = await narratorPage('key: "bernard-gabay"')
    expect(page?.catalogue?.biography).toBe('Voix de Dune.')
    expect(modelCalls).toEqual([])
  })

  test('keeps the face chosen by hand after a miss, with no further model call', async () => {
    modelAnswer = 'fails'
    await addBook(gabay)
    await narratorPage('key: "bernard-gabay"')
    await correct('portraitUrl: "https://example.com/gabay.jpg"')
    expect((await narratorPage('key: "bernard-gabay"'))?.narrator.portraitUrl).toBe(
      'https://example.com/gabay.jpg',
    )
    expect(modelCalls).toEqual(['Bernard Gabay'])
  })

  test('refuses an address that leads to a page', async () => {
    await addBook(gabay)
    const result = await correct('portraitUrl: "https://example.com/page"')
    expect(result.errors?.[0]?.extensions?.code).toBe('PORTRAIT_NOT_AN_IMAGE')
  })

  test('is not found for a narrator the reader holds nothing of', async () => {
    const result = await correct('biography: "Voix de Dune."')
    expect(result.errors?.[0]?.extensions?.code).toBe('NOT_FOUND')
  })

  test('offers the face drawn now first, then Wikipedia’s', async () => {
    await addBook(gabay)
    await narratorPage('key: "bernard-gabay"')
    await correct('portraitUrl: "https://example.com/gabay.jpg"')
    const result = await execute(
      '{ narratorPortraitChoices(key: "bernard-gabay") { source url isCurrent } }',
    )
    expect(result.data).toEqual({
      narratorPortraitChoices: [
        { source: 'WEB', url: 'https://example.com/gabay.jpg', isCurrent: true },
        { source: 'WIKIPEDIA', url: 'https://upload.wikimedia.org/gabay.jpg', isCurrent: false },
      ],
    })
  })
})

describe('the Library tab', () => {
  const narratorsRail = async (args = '') => {
    const result = await execute(
      `{ libraryShelves${args} { narrators { key name portraitUrl bookCount } } }`,
    )
    expect(result.errors).toBeUndefined()
    return (result.data as { libraryShelves: { narrators: unknown[] } }).libraryShelves.narrators
  }

  test('lines up who reads the recordings, the one shelved last first, with their faces', async () => {
    await addBook(
      'title: "Dune", authors: ["Frank Herbert"], format: AUDIOBOOK, narrators: ["Bernard Gabay"]',
    )
    await narratorPage('key: "bernard-gabay"')
    await addBook(
      'title: "Fondation", authors: ["Isaac Asimov"], format: AUDIOBOOK, narrators: ["Frédéric Kneip"]',
    )
    await addBook('title: "La Peste", authors: ["Albert Camus"]')

    expect(await narratorsRail()).toEqual([
      { key: 'frederic-kneip', name: 'Frédéric Kneip', portraitUrl: null, bookCount: 1 },
      {
        key: 'bernard-gabay',
        name: 'Bernard Gabay',
        portraitUrl: 'https://upload.wikimedia.org/gabay.jpg',
        bookCount: 1,
      },
    ])
    // Drawn from the stored faces: nothing is asked of the model or Wikipedia.
    expect(modelCalls).toEqual(['Bernard Gabay'])
  })

  test('is empty under a view that holds no recording', async () => {
    await addBook(
      'title: "Dune", authors: ["Frank Herbert"], format: AUDIOBOOK, narrators: ["Bernard Gabay"]',
    )
    expect(await narratorsRail('(format: BOOK)')).toEqual([])
  })
})
