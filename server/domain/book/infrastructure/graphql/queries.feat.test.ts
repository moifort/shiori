import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { graphql } from 'graphql'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

// The reader's own photo is signed by the object store, which needs a bucket.
mock.module('~/system/object-store', () => ({
  objectStore: () => ({ downloadUrl: async () => 'https://fake.store/cover' }),
}))

const { schema } = await import('~/domain/shared/graphql/schema')

const userId = 'reader-1' as UserId

beforeEach(() => {
  resetFakeFirestore()
})

const execute = (source: string) => graphql({ schema, source, contextValue: { event: {}, userId } })

const addBook = async (input: string) => {
  const result = await execute(`mutation { addBook(input: { ${input} }) { id } }`)
  expect(result.errors).toBeUndefined()
  return (result.data as { addBook: { id: string } }).addBook.id
}

describe('the library search', () => {
  test('hands the whole library with its sagas, and no cover', async () => {
    await addBook(
      'title: "Dungeon Crawler Carl", authors: ["Matt Dinniman"], ' +
        'coverUrl: "https://covers.example/dcc.jpg", ' +
        'series: { id: "dungeon-crawler-carl--matt-dinniman", name: "Dungeon Crawler Carl", volume: 1, kind: MAIN }',
    )
    await addBook('title: "Le Nom du vent", authors: ["Patrick Rothfuss"]')

    const result = await execute(
      '{ librarySearchIndex { title authors coverUrl series { name volume } } }',
    )

    expect(result.errors).toBeUndefined()
    const index = (
      result.data as { librarySearchIndex: ({ title: string } & Record<string, unknown>)[] }
    ).librarySearchIndex
    expect([...index].sort((a, b) => a.title.localeCompare(b.title))).toEqual([
      {
        title: 'Dungeon Crawler Carl',
        authors: ['Matt Dinniman'],
        coverUrl: null,
        series: { name: 'Dungeon Crawler Carl', volume: 1 },
      },
      { title: 'Le Nom du vent', authors: ['Patrick Rothfuss'], coverUrl: null, series: null },
    ])
  })

  test('signs the covers of the rows asked for', async () => {
    const covered = await addBook(
      'title: "Dungeon Crawler Carl", coverUrl: "https://covers.example/dcc.jpg"',
    )
    const bare = await addBook('title: "Le Nom du vent"')

    const result = await execute(`{ bookCovers(ids: ["${covered}", "${bare}"]) { id coverUrl } }`)

    expect(result.errors).toBeUndefined()
    expect(result.data).toEqual({
      bookCovers: [
        { id: covered, coverUrl: 'https://covers.example/dcc.jpg' },
        { id: bare, coverUrl: null },
      ],
    })
  })

  test('refuses more than fifty covers at once', async () => {
    const ids = Array.from({ length: 51 }, (_, index) => `"book-${index}"`).join(', ')

    const result = await execute(`{ bookCovers(ids: [${ids}]) { id } }`)

    expect(result.errors?.[0]?.extensions?.code).toBe('BAD_USER_INPUT')
  })
})
