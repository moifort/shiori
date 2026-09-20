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

/** A volume catalogued the way an Audible import or a manual entry catalogues
 *  one: it names its saga and nothing describes that saga anywhere. */
const addVolume = async (
  title: string,
  volume: number,
  options: { author?: string; language?: string } = {},
) => {
  const { author = 'Frank Herbert', language } = options
  const result = await execute(
    `mutation { addBook(input: {
      title: "${title}"
      authors: ["${author}"]
      ${language ? `language: ${language}` : ''}
      series: { id: "dune--frank-herbert", name: "Dune", volume: ${volume}, kind: MAIN }
    }) { id } }`,
  )
  expect(result.errors).toBeUndefined()
  return (result.data as { addBook: { id: string } }).addBook
}

/** Only the fields a given assertion asks for come back, so every one of these
 *  is optional: a query that selects four columns must not have to spell out the
 *  three it deliberately left out. */
type FollowedRow = {
  id: string
  name: string
  author?: string | null
  language?: string | null
  state?: string | null
  ownedCount: number
  catalogue?: { name: string } | null
}

const mySeries = async () => {
  const result = await execute(
    '{ mySeries { id name author state ownedCount catalogue { name } } }',
  )
  expect(result.errors).toBeUndefined()
  return (result.data as { mySeries: FollowedRow[] }).mySeries
}

describe('the sagas a reader follows', () => {
  // The defect: mySeries used to start from the catalogue, so a saga nobody had
  // ever scanned — every saga an Audible import produces — was absent from the
  // Series tab even though its volumes sat in the library.
  test('follows a saga that has never been catalogued', async () => {
    await addVolume('Dune', 1)
    await addVolume('Le Messie de Dune', 2)

    expect(await mySeries()).toEqual([
      {
        id: 'dune--frank-herbert',
        name: 'Dune',
        author: 'Frank Herbert',
        state: null,
        ownedCount: 2,
        catalogue: null,
      },
    ])
  })

  test('leaves a library of standalone books with no saga to follow', async () => {
    const result = await execute('mutation { addBook(input: { title: "Piranesi" }) { id } }')
    expect(result.errors).toBeUndefined()

    expect(await mySeries()).toEqual([])
  })
})

describe('a saga held in more than one language', () => {
  const followedLanguages = async () => {
    const result = await execute('{ mySeries { id name language ownedCount } }')
    expect(result.errors).toBeUndefined()
    return (result.data as { mySeries: FollowedRow[] }).mySeries
  }

  // Two translations of one saga are two sets of books — other covers, other
  // titles, read at other times — and one row over both hid that.
  test('follows it once per language, sharing one saga id', async () => {
    await addVolume('Dune', 1, { language: 'FR' })
    await addVolume('Dune', 1, { language: 'EN' })

    expect(await followedLanguages()).toEqual([
      { id: 'dune--frank-herbert', name: 'Dune', language: 'EN', ownedCount: 1 },
      { id: 'dune--frank-herbert', name: 'Dune', language: 'FR', ownedCount: 1 },
    ])
  })

  // Unknown is not French: a book catalogued before the scan read languages
  // carries none, and folding it into a language would state what nobody knows.
  test('keeps volumes of unrecorded language in a row of their own, last', async () => {
    await addVolume('Dune', 1, { language: 'FR' })
    await addVolume('Le Messie de Dune', 2)

    expect((await followedLanguages()).map((row) => row.language)).toEqual(['FR', null])
  })

  test('shows one section per language in the library', async () => {
    await addVolume('Dune', 1, { language: 'FR' })
    await addVolume('Dune', 1, { language: 'EN' })

    const result = await execute('{ library { seriesId language books { title } } }')
    expect(result.errors).toBeUndefined()
    expect(result.data?.library).toEqual([
      { seriesId: 'dune--frank-herbert', language: 'EN', books: [{ title: 'Dune' }] },
      { seriesId: 'dune--frank-herbert', language: 'FR', books: [{ title: 'Dune' }] },
    ])
  })
})
