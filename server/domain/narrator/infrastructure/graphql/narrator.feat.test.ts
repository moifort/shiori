import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { graphql } from 'graphql'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/domain/scan/bnf', () => ({ bnfEditionsOf: async () => [] }))
mock.module('~/system/object-store', () => ({
  objectStore: () => ({ downloadUrl: async () => 'https://fake.store/cover' }),
}))
mock.module('~/domain/scan/gemini', () => ({
  generate: async ({ step }: { step: string }) => {
    throw new Error(`no model call expected, got "${step}"`)
  },
}))
mock.module('~/domain/scan/open-library', () => ({
  openLibraryIsbnsOf: async () => [],
  openLibraryCoverOf: async () => undefined,
  openLibraryCoverByTitle: async () => undefined,
}))
/** The names Wikipedia was asked about, in order. */
const portraitSearches: string[] = []
let wikipediaHasFace = true
mock.module('~/domain/author/infrastructure/wikipedia', () => ({
  portraitOf: async (name: string) => {
    portraitSearches.push(name)
    return wikipediaHasFace ? 'https://upload.wikimedia.org/gabay.jpg' : undefined
  },
}))

const { schema } = await import('~/domain/shared/graphql/schema')

const userId = 'reader-1' as UserId
beforeEach(() => {
  resetFakeFirestore()
  portraitSearches.length = 0
  wikipediaHasFace = true
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
  sagas: { id: string; name: string }[]
  books: { title: string }[]
}

const narratorPage = async (args: string) => {
  const result = await execute(
    `{ narratorPage(${args}) {
      narrator { key name portraitUrl favorite bookCount readCount seriesCount averageRating }
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

  test('asks Wikipedia once, then reads the stored face', async () => {
    await addBook(
      'title: "Dune", authors: ["Frank Herbert"], format: AUDIOBOOK, narrators: ["Bernard Gabay"]',
    )
    await narratorPage('key: "bernard-gabay"')
    await narratorPage('key: "bernard-gabay"')
    expect(portraitSearches).toEqual(['Bernard Gabay'])
  })

  test('remembers a miss rather than asking again at every opening', async () => {
    wikipediaHasFace = false
    await addBook(
      'title: "Dune", authors: ["Frank Herbert"], format: AUDIOBOOK, narrators: ["Bernard Gabay"]',
    )
    expect((await narratorPage('key: "bernard-gabay"'))?.narrator.portraitUrl).toBeNull()
    await narratorPage('key: "bernard-gabay"')
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
