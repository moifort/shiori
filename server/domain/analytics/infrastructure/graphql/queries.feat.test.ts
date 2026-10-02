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
        lastFinished { title rating }
        toReadCount
        readCount
        averageRating
        ratedCount
        genres { genre count }
        favoriteCount
        hasAudiobooks
        hasPrintedBooks
        libraryIsEmpty
      }
    }`)

    expect(result.errors).toBeUndefined()
    const year = new Date().getFullYear()
    expect(result.data?.dashboard).toEqual({
      booksPerYear: [
        { year: year - 8, count: 0 },
        { year: year - 7, count: 0 },
        { year: year - 6, count: 0 },
        { year: year - 5, count: 0 },
        { year: year - 4, count: 0 },
        { year: year - 3, count: 0 },
        { year: year - 2, count: 0 },
        { year: year - 1, count: 0 },
        { year, count: 1 },
      ],
      reading: [{ title: 'La Peur du sage' }],
      lastFinished: { title: 'Le Nom du vent', rating: 5 },
      toReadCount: 1,
      readCount: 1,
      averageRating: 5,
      ratedCount: 1,
      genres: [{ genre: 'FANTASY', count: 1 }],
      favoriteCount: 0,
      hasAudiobooks: false,
      hasPrintedBooks: true,
      libraryIsEmpty: false,
    })
  })

  // A printed library listens to nothing, and the chart draws twelve empty bars
  // rather than disappearing.
  test('serves twelve months of listening hours, empty without an audiobook', async () => {
    await addBook('title: "Le Nom du vent", status: READ, pageCount: 662')

    const result = await execute(
      '{ dashboard(timeZone: "Europe/Paris") { hoursPerMonth { month hours } } }',
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.dashboard).toEqual({
      hoursPerMonth: Array.from({ length: 12 }, (_, index) => ({ month: index + 1, hours: 0 })),
    })
  })

  test('refuses a time zone the server does not know', async () => {
    const result = await execute('{ dashboard(timeZone: "Mars/Olympus") { libraryIsEmpty } }')

    expect(result.errors?.[0].message).toContain('TimeZone')
  })

  test('counts a hearted book and a hearted saga together', async () => {
    const id = await addBook('title: "Dune", format: AUDIOBOOK')
    await execute(`mutation { setBookFavorite(id: "${id}", favorite: true) { id } }`)
    await execute(
      'mutation { setSeriesFavorite(seriesId: "dune--frank-herbert", favorite: true) { favorite } }',
    )

    const result = await execute(
      '{ dashboard(timeZone: "Europe/Paris") { favoriteCount hasAudiobooks hasPrintedBooks } }',
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.dashboard).toEqual({
      favoriteCount: 2,
      hasAudiobooks: true,
      hasPrintedBooks: false,
    })
  })

  // Every mutation that changes a book must flag the view for the next read to
  // rebuild: one that forgot would silently serve yesterday's figures until the
  // next unrelated write.
  test('is flagged stale by every mutation that changes a book', async () => {
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
        stale: true,
      })
    }
  })
})

describe('the genre insights through the API', () => {
  test('serves the genres, formats and taste map of the books read', async () => {
    for (const rating of [4, 5, 5]) {
      const id = await addBook('title: "Fondation", status: READ, genre: SCIENCE_FICTION')
      await execute(`mutation { rateBook(id: "${id}", rating: ${rating}) { id } }`)
    }
    await addBook('title: "Dune", status: READ, genre: SCIENCE_FICTION, format: AUDIOBOOK')
    await addBook('title: "Les Misérables", status: TO_READ, genre: HISTORICAL_FICTION')

    const result = await execute(`{
      genreInsights {
        readCount
        shares { genre count }
        formats { format count topGenre }
        tastes { genre readCount averageRating }
        averageRating
        hiddenGem
        longest { genre averagePages }
        unexplored { genre pileCount }
      }
    }`)

    expect(result.errors).toBeUndefined()
    const { unexplored, ...insights } = (result.data?.genreInsights ?? {}) as {
      unexplored: { genre: string; pileCount: number }[]
    }
    expect({ ...insights, unexplored: unexplored[0] } as Record<string, unknown>).toEqual({
      readCount: 4,
      shares: [{ genre: 'SCIENCE_FICTION', count: 4 }],
      formats: [
        { format: 'BOOK', count: 3, topGenre: 'SCIENCE_FICTION' },
        { format: 'AUDIOBOOK', count: 1, topGenre: 'SCIENCE_FICTION' },
      ],
      tastes: [{ genre: 'SCIENCE_FICTION', readCount: 4, averageRating: 4.7 }],
      averageRating: 4.7,
      hiddenGem: null,
      longest: null,
      unexplored: { genre: 'HISTORICAL_FICTION', pileCount: 1 },
    })
  })

  // Nothing stored: the page reads the library once, whatever its size.
  test('reads the library in one query and writes nothing', async () => {
    await addBook('title: "Fondation", status: READ, genre: SCIENCE_FICTION')
    const writes = fake.batches.length
    const queries = fake.queryReads

    const result = await execute('{ genreInsights { readCount } }')

    expect(result.errors).toBeUndefined()
    expect(fake.queryReads - queries).toBe(1)
    expect(fake.batches.length).toBe(writes)
  })
})

describe('the taste map through the API', () => {
  test('places a subgenre with three rated books apart, and may name it the gem', async () => {
    const rated = async (fields: string, rating: number) => {
      const id = await addBook(`title: "Livre", status: READ, ${fields}`)
      await execute(`mutation { rateBook(id: "${id}", rating: ${rating}) { id } }`)
    }
    for (const rating of [4, 4, 4, 4, 4, 4]) await rated('genre: FANTASY', rating)
    for (const rating of [3, 4, 3, 4, 3]) await rated('genre: CRIME', rating)
    for (const rating of [5, 5, 5]) {
      await rated('genre: HISTORICAL_FICTION, subgenres: ["Uchronie"]', rating)
    }

    const result = await execute(`{
      genreInsights {
        tasteMap { genre subgenre readCount }
        gem { genre subgenre averageRating }
        hiddenGem
      }
    }`)

    expect(result.errors).toBeUndefined()
    expect(result.data?.genreInsights).toEqual({
      tasteMap: [
        { genre: 'FANTASY', subgenre: null, readCount: 6 },
        { genre: 'CRIME', subgenre: null, readCount: 5 },
        { genre: 'HISTORICAL_FICTION', subgenre: 'Uchronie', readCount: 3 },
      ],
      gem: { genre: 'HISTORICAL_FICTION', subgenre: 'Uchronie', averageRating: 5 },
      hiddenGem: 'HISTORICAL_FICTION',
    })
  })
})
