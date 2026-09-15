import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { graphql } from 'graphql'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

// Covers are signed by the real object store, which needs a bucket. The library
// is what is under test here, not the signing, so it is stubbed away.
mock.module('~/system/object-store', () => ({
  objectStore: () => ({ downloadUrl: async () => 'https://fake.store/cover' }),
}))

const { schema } = await import('~/domain/shared/graphql/schema')

const userId = 'reader-1' as UserId

beforeEach(() => {
  resetFakeFirestore()
})

const execute = (source: string) => graphql({ schema, source, contextValue: { event: {}, userId } })

const addBook = async (title: string, status = 'TO_READ') => {
  const result = await execute(
    `mutation { addBook(input: { title: "${title}", status: ${status} }) { id title status } }`,
  )
  expect(result.errors).toBeUndefined()
  return (result.data as { addBook: { id: string } }).addBook
}

describe('cataloguing through the API', () => {
  test('adds a book and returns it on the pile', async () => {
    const result = await execute(
      'mutation { addBook(input: { title: "Le Nom du vent" }) { title status hidden rating } }',
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.addBook).toEqual({
      title: 'Le Nom du vent',
      status: 'TO_READ',
      hidden: false,
      rating: null,
    })
  })

  test('catalogues a manga as a manga, and a correction changes only the format', async () => {
    const created = await execute(
      'mutation { addBook(input: { title: "One Piece", format: MANGA }) { id format } }',
    )
    expect(created.errors).toBeUndefined()
    const book = (created.data as { addBook: { id: string; format: string } }).addBook
    expect(book.format).toBe('MANGA')

    const corrected = await execute(
      `mutation { updateBook(id: "${book.id}", input: { format: BANDE_DESSINEE }) { title format } }`,
    )

    expect(corrected.errors).toBeUndefined()
    expect(corrected.data?.updateBook).toEqual({ title: 'One Piece', format: 'BANDE_DESSINEE' })
  })

  // The cover `scanBook` found rides back through `addBook`, and is what every
  // later read of the book draws.
  test('keeps the publisher cover a scan found and reads it back', async () => {
    const cover = 'https://covers.openlibrary.org/b/isbn/9782352943556-M.jpg?default=false'
    const created = await execute(
      `mutation { addBook(input: { title: "Le Nom du vent", coverUrl: "${cover}" }) { id coverUrl } }`,
    )
    expect(created.errors).toBeUndefined()
    const book = (created.data as { addBook: { id: string; coverUrl: string } }).addBook
    expect(book.coverUrl).toBe(cover)

    const read = await execute(`query { book(id: "${book.id}") { coverUrl } }`)

    expect(read.errors).toBeUndefined()
    expect(read.data?.book).toEqual({ coverUrl: cover })
  })

  test('draws no cover for a book typed by hand', async () => {
    const result = await execute('mutation { addBook(input: { title: "Sans ISBN" }) { coverUrl } }')

    expect(result.errors).toBeUndefined()
    expect(result.data?.addBook).toEqual({ coverUrl: null })
  })

  test('refuses a cover served over plain HTTP, as bad input', async () => {
    const result = await execute(
      'mutation { addBook(input: { title: "Le Nom du vent", coverUrl: "http://example.com/c.jpg" }) { id } }',
    )

    expect(result.errors?.[0]?.extensions?.code).toBe('BAD_USER_INPUT')
  })

  // The scalar reuses the brand's Zod constructor, so a bad value must come back
  // as something the client can show, not as a 500.
  test('refuses an ISBN whose check digit does not match, as bad input', async () => {
    const book = await addBook('Le Nom du vent')

    const result = await execute(
      `mutation { updateBook(id: "${book.id}", input: { isbn13: "9780756404742" }) { id } }`,
    )

    expect(result.errors?.[0]?.extensions?.code).toBe('BAD_USER_INPUT')
  })

  test('reports a book the reader does not own as NOT_FOUND', async () => {
    const result = await execute('mutation { rateBook(id: "does-not-exist", rating: 4) { id } }')

    expect(result.errors?.[0]?.extensions?.code).toBe('NOT_FOUND')
  })
})

describe('rating through the API', () => {
  test('marks the book read and stamps both reading dates', async () => {
    const book = await addBook('Le Nom du vent')

    const result = await execute(
      `mutation { rateBook(id: "${book.id}", rating: 5) { rating status startedAt finishedAt } }`,
    )

    expect(result.errors).toBeUndefined()
    const rated = result.data?.rateBook as Record<string, unknown>
    expect(rated.rating).toBe(5)
    expect(rated.status).toBe('READ')
    expect(rated.startedAt).not.toBeNull()
    expect(rated.finishedAt).not.toBeNull()
  })

  test('takes the rating back without moving the book off the read pile', async () => {
    const book = await addBook('Le Nom du vent')
    await execute(`mutation { rateBook(id: "${book.id}", rating: 5) { id } }`)

    const result = await execute(
      `mutation { removeBookRating(id: "${book.id}") { rating status } }`,
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.removeBookRating).toEqual({ rating: null, status: 'READ' })
  })
})

describe('correcting a book through the API', () => {
  const addDetailedBook = async () => {
    const result = await execute(
      'mutation { addBook(input: { title: "Blacksad", authors: ["Juan Díaz Canales"], ' +
        'publisher: "Dargaud", firstPublishedIn: 2000, synopsis: "Un chat détective.", ' +
        'genres: ["Polar"], pageCount: 56, isbn13: "9782205049824" }) { id } }',
    )
    expect(result.errors).toBeUndefined()
    return (result.data as { addBook: { id: string } }).addBook
  }

  test('clears every optional field passed as null, and leaves omitted ones alone', async () => {
    const book = await addDetailedBook()

    const result = await execute(
      `mutation { updateBook(id: "${book.id}", input: { publisher: null, firstPublishedIn: null, ` +
        'synopsis: null, pageCount: null, isbn13: null, genres: null }) ' +
        '{ title authors publisher firstPublishedIn synopsis pageCount isbn13 genres } }',
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.updateBook).toEqual({
      title: 'Blacksad',
      authors: ['Juan Díaz Canales'],
      publisher: null,
      firstPublishedIn: null,
      synopsis: null,
      pageCount: null,
      isbn13: null,
      genres: [],
    })
  })

  test('replaces the authors with none when an empty list is passed', async () => {
    const book = await addDetailedBook()

    const result = await execute(
      `mutation { updateBook(id: "${book.id}", input: { authors: [] }) { authors } }`,
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.updateBook).toEqual({ authors: [] })
  })

  // A title is what makes a record a book: it can be corrected, never removed.
  test('ignores a null title rather than erasing it', async () => {
    const book = await addDetailedBook()

    const result = await execute(
      `mutation { updateBook(id: "${book.id}", input: { title: null }) { title } }`,
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.updateBook).toEqual({ title: 'Blacksad' })
  })
})

describe('reading the library through the API', () => {
  test('returns standalone books on a shelf with no series', async () => {
    await addBook('Le Nom du vent')

    const result = await execute('{ library { series books { title } } }')

    expect(result.errors).toBeUndefined()
    expect(result.data?.library).toEqual([{ series: null, books: [{ title: 'Le Nom du vent' }] }])
  })

  test('narrows the library to one reading status', async () => {
    await addBook('En cours', 'READING')
    await addBook('Sur la pile')

    const result = await execute('{ library(status: READING) { books { title } } }')

    expect(result.errors).toBeUndefined()
    expect(result.data?.library).toEqual([{ books: [{ title: 'En cours' }] }])
  })

  test('surfaces what is open right now', async () => {
    await addBook('En cours', 'READING')
    await addBook('Sur la pile')

    const result = await execute('{ currentlyReading { title } }')

    expect(result.errors).toBeUndefined()
    expect(result.data?.currentlyReading).toEqual([{ title: 'En cours' }])
  })

  test('has no saga to show before any book carries one', async () => {
    await addBook('Le Nom du vent')

    const result = await execute('{ mySeries { state ownedCount } }')

    expect(result.errors).toBeUndefined()
    expect(result.data?.mySeries).toEqual([])
  })
})

describe('a book that came from a scan', () => {
  // The scan resolves the saga server-side and hands it to the app; addBook is
  // the only way it comes back. Without this field a scanned book never joined
  // its series, and the library never grouped it.
  test('keeps the series it was scanned with, and groups under it', async () => {
    const result = await execute(`
      mutation {
        addBook(input: {
          title: "Le Nom du vent"
          authors: ["Patrick Rothfuss"]
          series: {
            id: "chronique-du-tueur-de-roi--patrick-rothfuss"
            name: "Chronique du tueur de roi"
            volume: 1
            kind: MAIN
          }
        }) { series { name volume kind } }
      }
    `)

    expect(result.errors).toBeUndefined()
    expect(result.data?.addBook).toEqual({
      series: { name: 'Chronique du tueur de roi', volume: 1, kind: 'MAIN' },
    })

    const library = await execute('{ library { series books { title } } }')
    expect(library.data?.library).toEqual([
      { series: 'Chronique du tueur de roi', books: [{ title: 'Le Nom du vent' }] },
    ])
  })
})

describe('keeping a book to oneself', () => {
  test('flips the hidden flag', async () => {
    const book = await addBook('Le Nom du vent')

    const result = await execute(
      `mutation { setBookHidden(id: "${book.id}", hidden: true) { hidden } }`,
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.setBookHidden).toEqual({ hidden: true })
  })
})
