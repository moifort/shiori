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

describe('correctAuthor', () => {
  test('writes the fields passed, clears those passed as null, and answers the page', async () => {
    fake.seed('authors', 'frank-herbert', {
      key: 'frank-herbert',
      name: 'Frank Herbert',
      nationality: 'Britannique',
      biography: 'Auteur de polars.',
      portraitUrl: 'https://upload.wikimedia.org/herbert.jpg',
      series: [],
      books: [],
      cataloguedAt: new Date('2026-10-01'),
    })
    await execute(
      `mutation { addBook(input: { title: "Dune", authors: ["Frank Herbert"] }) { id } }`,
    )

    const result = await execute(
      `mutation { correctAuthor(key: "frank-herbert", biography: "Auteur de Dune.", nationality: null, birthYear: 1920) {
        catalogue { biography nationality birthYear portraitUrl }
      } }`,
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.correctAuthor).toEqual({
      catalogue: {
        biography: 'Auteur de Dune.',
        nationality: null,
        birthYear: 1920,
        portraitUrl: 'https://upload.wikimedia.org/herbert.jpg',
      },
    })
  })

  test('is not found for an author the reader holds nothing of', async () => {
    const result = await execute(
      `mutation { correctAuthor(key: "frank-herbert", biography: "Auteur.") { author { name } } }`,
    )

    expect(result.errors?.[0].extensions?.code).toBe('NOT_FOUND')
  })
})
