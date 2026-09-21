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

const execute = (source: string, variableValues?: Record<string, unknown>) =>
  graphql({ schema, source, contextValue: { event: {}, userId }, variableValues })

// Quoted fields, an accent and a name filed surname first: what an export
// really looks like, passed as a variable so the file is never a literal.
const EXPORT = ['Product Name,Author Name', 'Dune,"Herbert, Frank"', 'Hypérion,Dan Simmons'].join(
  '\n',
)

const read = async (csv = EXPORT) => {
  const result = await execute(
    'mutation Read($csv: String!) { readKindleExport(csv: $csv) { key title authors alreadyInLibrary } }',
    { csv },
  )
  expect(result.errors).toBeUndefined()
  return result.data?.readKindleExport as {
    key: string
    title: string
    authors: string[]
    alreadyInLibrary: boolean
  }[]
}

const importBooks = (keys: string[], fields = 'id') =>
  execute(
    `mutation Import($csv: String!, $keys: [String!]!) { importKindleBooks(csv: $csv, keys: $keys) { ${fields} } }`,
    { csv: EXPORT, keys },
  )

describe('reading an Amazon data export', () => {
  test('answers the books it holds and saves nothing', async () => {
    const found = await read()

    expect(found.map((book) => book.title)).toEqual(['Dune', 'Hypérion'])
    expect(found[0].authors).toEqual(['Frank Herbert'])
    expect(found.every((book) => !book.alreadyInLibrary)).toBe(true)

    const library = await execute('{ library { books { title } } }')
    expect(library.data?.library).toEqual([])
  })

  test('ticks off a title the reader already owns', async () => {
    await execute(
      'mutation { addBook(input: { title: "Dune", authors: ["Frank Herbert"] }) { id } }',
    )

    const found = await read()

    expect(found.find((book) => book.title === 'Dune')?.alreadyInLibrary).toBe(true)
    expect(found.find((book) => book.title === 'Hypérion')?.alreadyInLibrary).toBe(false)
  })

  // The archive holds several files and only one of them is the library.
  test('refuses a file with no column that could hold a title', async () => {
    const result = await execute(
      'mutation Read($csv: String!) { readKindleExport(csv: $csv) { title } }',
      { csv: 'Order Date,Total\n2026-01-01,12.99' },
    )

    expect(result.errors?.[0]?.extensions?.code).toBe('BAD_USER_INPUT')
  })
})

describe('importing from an Amazon data export', () => {
  test('catalogues the ticked titles as ebooks on the pile', async () => {
    const found = await read()

    const result = await importBooks([found[0].key], 'title format status authors')

    expect(result.errors).toBeUndefined()
    expect(result.data?.importKindleBooks).toEqual([
      { title: 'Dune', format: 'EBOOK', status: 'TO_READ', authors: ['Frank Herbert'] },
    ])
  })

  // A second request must not be able to duplicate what is already on the shelf,
  // however the app ticked it.
  test('skips a title already owned however it was ticked', async () => {
    const keys = (await read()).map((book) => book.key)

    await importBooks(keys)
    const again = await importBooks(keys)

    expect(again.errors).toBeUndefined()
    expect(again.data?.importKindleBooks).toEqual([])
    const library = await execute('{ library { books { title } } }')
    expect((library.data?.library as { books: unknown[] }[])[0].books).toHaveLength(2)
  })

  // The dashboard counts what the library holds, so an import of a hundred
  // books must leave it counting them.
  test('rebuilds the dashboard after the books land', async () => {
    const found = await read()

    await importBooks([found[0].key])

    const dashboard = await execute('{ dashboard(timeZone: "Europe/Paris") { toReadCount } }')
    expect(dashboard.data?.dashboard).toEqual({ toReadCount: 1 })
  })
})
