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
const addVolume = async (title: string, volume: number, author = 'Frank Herbert') => {
  const result = await execute(
    `mutation { addBook(input: {
      title: "${title}"
      authors: ["${author}"]
      series: { id: "dune--frank-herbert", name: "Dune", volume: ${volume}, kind: MAIN }
    }) { id } }`,
  )
  expect(result.errors).toBeUndefined()
  return (result.data as { addBook: { id: string } }).addBook
}

type FollowedRow = {
  id: string
  name: string
  author: string | null
  state: string | null
  ownedCount: number
  catalogue: { name: string } | null
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
