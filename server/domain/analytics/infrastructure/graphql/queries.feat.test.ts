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
let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const execute = (source: string) => graphql({ schema, source, contextValue: { event: {}, userId } })

const addBook = async (fields: string) => {
  const result = await execute(`mutation { addBook(input: { ${fields} }) { id } }`)
  expect(result.errors).toBeUndefined()
  return (result.data as { addBook: { id: string } }).addBook.id
}

describe('the dashboard through the API', () => {
  test('serves the shelves and statistics of the library', async () => {
    await addBook('title: "La Peur du sage", status: READING')
    await addBook('title: "Hypérion", status: TO_READ')
    const read = await addBook(
      'title: "Le Nom du vent", status: READING, pageCount: 662, genre: FANTASY',
    )
    await execute(`mutation { rateBook(id: "${read}", rating: 5) { id } }`)

    const result = await execute(`{
      dashboard(timeZone: "Europe/Paris") {
        booksPerYear { year count }
        reading { title }
        suggestions { title }
        lastFinished { title rating }
        toReadCount
        averageRating
        ratedCount
        genres { genre count }
        libraryIsEmpty
      }
    }`)

    expect(result.errors).toBeUndefined()
    const year = new Date().getFullYear()
    expect(result.data?.dashboard).toEqual({
      booksPerYear: [
        { year: year - 5, count: 0 },
        { year: year - 4, count: 0 },
        { year: year - 3, count: 0 },
        { year: year - 2, count: 0 },
        { year: year - 1, count: 0 },
        { year, count: 1 },
      ],
      reading: [{ title: 'La Peur du sage' }],
      suggestions: [{ title: 'Hypérion' }],
      lastFinished: { title: 'Le Nom du vent', rating: 5 },
      toReadCount: 1,
      averageRating: 5,
      ratedCount: 1,
      genres: [{ genre: 'FANTASY', count: 1 }],
      libraryIsEmpty: false,
    })
  })

  test('refuses a time zone the server does not know', async () => {
    const result = await execute('{ dashboard(timeZone: "Mars/Olympus") { libraryIsEmpty } }')

    expect(result.errors?.[0].message).toContain('TimeZone')
  })

  // Every mutation that changes a book must leave the view fresh: one that forgot
  // would silently serve yesterday's figures until the next unrelated write.
  test('is rebuilt by every mutation that changes a book', async () => {
    const id = await addBook('title: "Le Nom du vent"')
    const mutations = [
      `updateBook(id: "${id}", input: { title: "Le Nom du vent (poche)" }) { id }`,
      `setReadingStatus(id: "${id}", status: READING) { id }`,
      `rateBook(id: "${id}", rating: 4) { id }`,
      `removeBookRating(id: "${id}") { id }`,
      `setBookNote(id: "${id}", note: "Magnifique") { id }`,
      `setBookHidden(id: "${id}", hidden: true) { id }`,
      `deleteBook(id: "${id}")`,
    ]

    for (const mutation of mutations) {
      const committed = fake.batches.length
      const result = await execute(`mutation { ${mutation} }`)
      expect(result.errors).toBeUndefined()
      const staled = fake.batches
        .slice(committed)
        .some((batch) => batch.ops.some((op) => op.ref.collectionPath === 'analytics'))
      expect({ mutation, staled, stale: fake.data('analytics', userId)?.stale }).toEqual({
        mutation,
        staled: true,
        stale: false,
      })
    }
  })
})
