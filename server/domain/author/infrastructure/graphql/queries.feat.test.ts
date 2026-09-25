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
let fake: ReturnType<typeof resetFakeFirestore>

beforeEach(() => {
  fake = resetFakeFirestore()
})

const execute = (source: string) => graphql({ schema, source, contextValue: { event: {}, userId } })

const addBook = async (fields: string) => {
  const result = await execute(`mutation { addBook(input: { ${fields} }) { id } }`)
  expect(result.errors).toBeUndefined()
  return (result.data as { addBook: { id: string } }).addBook.id
}

type AuthorRow = {
  key: string
  name: string
  bookCount: number
  seriesCount: number
  favoriteCount: number
  averageRating: number | null
  books: { title: string; status: string }[]
}

const myAuthorsPage = async (args = 'limit: 40, offset: 0') => {
  const result = await execute(
    `{ myAuthorsPage(${args}) { hasMore items {
      key name bookCount seriesCount favoriteCount averageRating
      books { title status }
    } } }`,
  )
  expect(result.errors).toBeUndefined()
  return (result.data as { myAuthorsPage: { hasMore: boolean; items: AuthorRow[] } }).myAuthorsPage
}

describe('the Authors tab', () => {
  test('draws an author with their books and what the reader made of them', async () => {
    fake.seed('series', 'dune--frank-herbert', {
      id: 'dune--frank-herbert',
      name: 'Dune',
      author: 'Frank Herbert',
      volumes: [1, 2, 3].map((number) => ({ number, title: `Dune ${number}`, kind: 'main' })),
    })
    for (const [volume, status] of [
      [1, 'READ'],
      [2, 'READING'],
    ] as const)
      await addBook(
        `title: "Dune ${volume}", authors: ["Frank Herbert"], status: ${status},
         series: { id: "dune--frank-herbert", name: "Dune", volume: ${volume}, kind: MAIN }`,
      )
    await addBook('title: "The Dosadi Experiment", authors: ["Frank Herbert"]')
    const rated = await execute(
      'mutation { rateSeries(seriesId: "dune--frank-herbert", rating: 4) { seriesId } }',
    )
    expect(rated.errors).toBeUndefined()

    const { items, hasMore } = await myAuthorsPage()

    expect(hasMore).toBe(false)
    expect(items).toEqual([
      {
        key: 'frank-herbert',
        name: 'Frank Herbert',
        bookCount: 3,
        seriesCount: 1,
        favoriteCount: 0,
        averageRating: 4,
        books: expect.any(Array),
      },
    ])
    expect(items[0]?.books.map((book) => book.status).sort()).toEqual([
      'READ',
      'READING',
      'TO_READ',
    ])
  })

  test('ranks the authors with a heart first, and keeps only them in the favourites', async () => {
    const loved = await addBook('title: "Earthsea", authors: ["Ursula K. Le Guin"]')
    await addBook('title: "Mistborn", authors: ["Brandon Sanderson"]')
    const hearted = await execute(
      `mutation { setBookFavorite(id: "${loved}", favorite: true) { id } }`,
    )
    expect(hearted.errors).toBeUndefined()

    const all = await myAuthorsPage()
    expect(all.items.map((author) => author.name)).toEqual([
      'Ursula K. Le Guin',
      'Brandon Sanderson',
    ])

    const favorites = await myAuthorsPage('favorite: true')
    expect(favorites.items.map((author) => author.name)).toEqual(['Ursula K. Le Guin'])
  })

  test('cuts the pages from one order, with what follows', async () => {
    for (const name of ['A', 'B', 'C']) await addBook(`title: "${name}", authors: ["${name}"]`)

    const whole = await myAuthorsPage()
    const first = await myAuthorsPage('limit: 2, offset: 0')
    const second = await myAuthorsPage('limit: 2, offset: 2')

    expect(first).toEqual({ hasMore: true, items: whole.items.slice(0, 2) })
    expect(second).toEqual({ hasMore: false, items: whole.items.slice(2) })
  })
})
