import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { graphql } from 'graphql'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

mock.module('~/system/object-store', () => ({
  objectStore: () => ({ downloadUrl: async () => 'https://fake.store/cover' }),
}))

const { schema } = await import('~/domain/shared/graphql/schema')

const userId = 'reader-1' as UserId

beforeEach(() => {
  resetFakeFirestore()
})

const execute = (source: string) => graphql({ schema, source, contextValue: { event: {}, userId } })

const DUNE = 'dune--frank-herbert'

describe('what a reader makes of a saga, through the API', () => {
  // The stars drawn on a volume: its own, else the saga's, and the app knows
  // which is which, so the edit screen still sees an unrated book.
  test('lends the saga rating to a volume the reader left unrated', async () => {
    const added = await execute(
      `mutation { addBook(input: {
        title: "Dune"
        authors: ["Frank Herbert"]
        series: { id: "${DUNE}", name: "Dune", volume: 1, kind: MAIN }
      }) { id } }`,
    )
    const { id } = (added.data as { addBook: { id: string } }).addBook
    await execute(`mutation { rateSeries(seriesId: "${DUNE}", rating: 4) { rating } }`)

    const unrated = await execute(`{ book(id: "${id}") { rating seriesRating } }`)
    expect(unrated.errors).toBeUndefined()
    expect(unrated.data?.book).toEqual({ rating: null, seriesRating: 4 })

    await execute(`mutation { rateBook(id: "${id}", rating: 2) { id } }`)
    const rated = await execute(`{ book(id: "${id}") { rating seriesRating } }`)
    expect(rated.data?.book).toEqual({ rating: 2, seriesRating: 4 })
  })

  test('has no saga rating to lend to a standalone book', async () => {
    const added = await execute('mutation { addBook(input: { title: "Piranesi" }) { id } }')
    const { id } = (added.data as { addBook: { id: string } }).addBook

    const result = await execute(`{ book(id: "${id}") { seriesRating } }`)
    expect(result.data?.book).toEqual({ seriesRating: null })
  })

  test('rates a saga without touching any volume rating', async () => {
    const added = await execute(
      `mutation { addBook(input: {
        title: "Dune"
        authors: ["Frank Herbert"]
        series: { id: "${DUNE}", name: "Dune", volume: 1, kind: MAIN }
      }) { id rating } }`,
    )
    expect(added.errors).toBeUndefined()

    const rated = await execute(
      `mutation { rateSeries(seriesId: "${DUNE}", rating: 5) { rating favorite } }`,
    )

    expect(rated.errors).toBeUndefined()
    expect(rated.data?.rateSeries).toEqual({ rating: 5, favorite: false })
    const library = await execute('{ library { books { rating } } }')
    expect(library.data?.library).toEqual([{ books: [{ rating: null }] }])
  })

  // A saga nobody has catalogued is still one the reader is reading, and an
  // opinion of it is still theirs to hold.
  test('rates a saga the catalogue has never described', async () => {
    const result = await execute(
      `mutation { rateSeries(seriesId: "unknown--saga", rating: 3) { seriesId rating } }`,
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.rateSeries).toEqual({ seriesId: 'unknown--saga', rating: 3 })
  })

  test('answers with nothing until the reader has said something', async () => {
    const result = await execute(`{ seriesOpinion(seriesId: "${DUNE}") { rating } }`)

    expect(result.errors).toBeUndefined()
    expect(result.data?.seriesOpinion).toBeNull()
  })

  test('a heart survives the rating being taken back', async () => {
    await execute(
      `mutation { setSeriesFavorite(seriesId: "${DUNE}", favorite: true) { favorite } }`,
    )
    await execute(`mutation { rateSeries(seriesId: "${DUNE}", rating: 4) { rating } }`)
    await execute(`mutation { removeSeriesRating(seriesId: "${DUNE}") { rating } }`)

    const result = await execute(`{ seriesOpinion(seriesId: "${DUNE}") { rating favorite } }`)
    expect(result.data?.seriesOpinion).toEqual({ rating: null, favorite: true })
  })

  // The heading of a saga section is where the reader's heart and stars show
  // in the library, so the list carries them rather than asking per saga.
  test('shows on the saga heading of the library', async () => {
    await execute(
      `mutation { addBook(input: {
        title: "Dune"
        authors: ["Frank Herbert"]
        series: { id: "${DUNE}", name: "Dune", volume: 1, kind: MAIN }
      }) { id } }`,
    )
    await execute(`mutation { rateSeries(seriesId: "${DUNE}", rating: 4) { rating } }`)
    await execute(
      `mutation { setSeriesFavorite(seriesId: "${DUNE}", favorite: true) { favorite } }`,
    )

    const result = await execute('{ library { series opinion { rating favorite } } }')
    expect(result.errors).toBeUndefined()
    expect(result.data?.library).toEqual([
      { series: 'Dune', opinion: { rating: 4, favorite: true } },
    ])
  })

  // The catalogue is a fact about the world, shared by every reader of the saga.
  // An opinion is the one thing that must never reach it.
  test('keeps the opinion out of the shared catalogue', async () => {
    await execute(`mutation { rateSeries(seriesId: "${DUNE}", rating: 5) { rating } }`)

    const result = await execute(`{ series(id: "${DUNE}") { id } }`)
    expect(result.errors).toBeUndefined()
    expect(result.data?.series).toBeNull()
  })
})
