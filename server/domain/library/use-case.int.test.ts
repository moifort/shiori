import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore, startFakeRequest } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { BookCommand } = await import('~/domain/book/command')
const { BookQuery } = await import('~/domain/book/query')
const { LibraryUseCase } = await import('~/domain/library/use-case')
const { SeriesOpinionCommand } = await import('~/domain/series-opinion/command')
const { StarRating, Subgenre } = await import('~/domain/book/primitives')
const { AuthorName, BookTitle } = await import('~/domain/shared/primitives')
const { SagaKey, SeriesName, VolumeNumber } = await import('~/domain/series/primitives')

const reader = 'reader-1' as UserId
const NOW = new Date('2026-10-26T10:00:00.000Z')
const at = (days: number) => new Date(NOW.getTime() - days * 86_400_000)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
  startFakeRequest()
})

type Shelved = {
  title: string
  days: number
  status?: 'to-read' | 'reading' | 'read' | 'dropped'
  format?: 'book' | 'manga' | 'audiobook'
  genre?: 'science-fiction' | 'fantasy'
  subgenre?: string
  author?: string
  saga?: string
}

const shelve = async ({ title, days, status, format, genre, subgenre, author, saga }: Shelved) => {
  const book = await BookCommand.add(
    reader,
    {
      title: BookTitle(title),
      format,
      genre,
      authors: author ? [AuthorName(author)] : undefined,
      subgenres: subgenre ? [{ label: Subgenre(subgenre), language: 'fr' }] : undefined,
      series: saga
        ? {
            saga: SagaKey(`${saga.toLowerCase()}--x`),
            name: SeriesName(saga),
            volume: VolumeNumber(1),
            kind: 'main',
          }
        : undefined,
    },
    at(days),
  )
  if (status && status !== 'to-read') await BookCommand.setStatus(reader, book.id, status, at(days))
  return book
}

const titlesOf = (books: readonly { title: string }[]) => books.map((book) => String(book.title))

describe('the Library tab entry screen', () => {
  test('fills each rail from one scan of the library', async () => {
    await shelve({ title: 'Dune', days: 0 })
    await shelve({ title: 'Hypérion', days: 1, status: 'reading' })
    await shelve({ title: 'Fondation', days: 2, status: 'read' })
    await shelve({ title: 'Vagabond', days: 3, status: 'dropped' })
    startFakeRequest()
    const before = fake.queryReads

    const [recent, toRead, read, dropped] = await Promise.all([
      LibraryUseCase.rail(reader, {}, 'recent'),
      LibraryUseCase.rail(reader, {}, 'toRead'),
      LibraryUseCase.rail(reader, {}, 'readRecently'),
      LibraryUseCase.hasDropped(reader, {}),
    ])

    expect(titlesOf(recent)).toEqual(['Dune', 'Hypérion', 'Fondation', 'Vagabond'])
    expect(titlesOf(toRead)).toEqual(['Dune'])
    expect(titlesOf(read)).toEqual(['Fondation'])
    expect(dropped).toBe(true)
    expect(fake.queryReads - before).toBe(1)
  })

  test('narrows every rail to the format pill, and offers only the formats held', async () => {
    await shelve({ title: 'Frieren', days: 0, format: 'manga' })
    await shelve({ title: 'Dune', days: 1 })

    const recent = await LibraryUseCase.rail(reader, { format: 'manga' }, 'recent')
    const formats = await LibraryUseCase.formats(reader, { format: 'manga' })

    expect(titlesOf(recent)).toEqual(['Frieren'])
    expect(formats).toEqual(['book', 'manga'])
  })

  test('narrows a genre page to its subgenre, whatever its case', async () => {
    await shelve({ title: 'Dune', days: 0, genre: 'science-fiction', subgenre: 'Space opera' })
    await shelve({ title: 'Silo', days: 1, genre: 'science-fiction', subgenre: 'Dystopie' })
    await shelve({ title: 'Le Hobbit', days: 2, genre: 'fantasy' })

    const genre = await LibraryUseCase.rail(reader, { genre: 'science-fiction' }, 'recent')
    const sub = await LibraryUseCase.rail(
      reader,
      { genre: 'science-fiction', subgenre: Subgenre('space OPERA') },
      'recent',
    )
    const pills = await LibraryUseCase.subgenres(reader, { genre: 'science-fiction' }, 'fr')

    expect(titlesOf(genre)).toEqual(['Dune', 'Silo'])
    expect(titlesOf(sub)).toEqual(['Dune'])
    expect(pills.map(String).sort()).toEqual(['Dystopie', 'Space Opera'])
  })

  test('counts the genres, the most held first', async () => {
    await shelve({ title: 'Dune', days: 0, genre: 'science-fiction' })
    await shelve({ title: 'Silo', days: 1, genre: 'science-fiction' })
    await shelve({ title: 'Le Hobbit', days: 2, genre: 'fantasy' })

    const genres = await LibraryUseCase.genres(reader, {})

    expect(genres.map((shelf) => [shelf.genre, shelf.count])).toEqual([
      ['science-fiction', 2],
      ['fantasy', 1],
    ])
  })

  test('draws the series and the authors of the view, the one shelved last first', async () => {
    await shelve({ title: 'Frieren', days: 0, format: 'manga', saga: 'Frieren', author: 'Yamada' })
    await shelve({ title: 'Dune', days: 1, saga: 'Dune', author: 'Frank Herbert' })

    const series = await LibraryUseCase.series(reader, { format: 'manga' })
    const authors = await LibraryUseCase.authors(reader, {})

    expect(series.map((row) => String(row.name))).toEqual(['Frieren'])
    expect(authors.map((author) => String(author.name))).toEqual(['Yamada', 'Frank Herbert'])
  })
})

describe('a shelf of the Library tab narrowed by its pills', () => {
  test('keeps one format, read with its index', async () => {
    await shelve({ title: 'Frieren', days: 0, format: 'manga', status: 'read' })
    await shelve({ title: 'Dune', days: 1, status: 'read' })
    const before = fake.queriedDocs

    const { books } = await BookQuery.libraryPage(
      reader,
      { limit: 10 },
      { status: 'read', format: 'manga' },
    )

    expect(titlesOf(books)).toEqual(['Frieren'])
    // The page and the one document saying whether more follow, never the library.
    expect(fake.queriedDocs - before).toBe(1)
  })

  test('keeps one genre and pages through it', async () => {
    await shelve({ title: 'Dune', days: 0, genre: 'science-fiction' })
    await shelve({ title: 'Le Hobbit', days: 1, genre: 'fantasy' })
    const silo = await shelve({ title: 'Silo', days: 2, genre: 'science-fiction' })

    const first = await BookQuery.libraryPage(reader, { limit: 1 }, { genre: 'science-fiction' })
    const next = await BookQuery.libraryPage(
      reader,
      { limit: 1, after: first.books[0]?.id },
      { genre: 'science-fiction' },
    )

    expect(titlesOf(first.books)).toEqual(['Dune'])
    expect(first.hasMore).toBe(true)
    expect(next.books.map((book) => book.id)).toEqual([silo.id])
    expect(next.hasMore).toBe(false)
  })
})

describe('"Coups de cœur" with the hearted series', () => {
  const heartSagaOf = async (book: Awaited<ReturnType<typeof shelve>>) => {
    if (!book.series) throw new Error('no saga')
    await SeriesOpinionCommand.setFavorite(reader, book.series.saga, true)
  }

  test('draws a hearted saga whole and leaves its volumes out of the books', async () => {
    const rising = await shelve({ title: 'Red Rising', days: 0, status: 'read', saga: 'Rising' })
    const dune = await shelve({ title: 'Dune', days: 1, status: 'read' })
    const hyperion = await shelve({ title: 'Hypérion', days: 2, status: 'read', saga: 'Cantos' })
    for (const book of [rising, dune, hyperion])
      await BookCommand.setFavorite(reader, book.id, true)
    await heartSagaOf(rising)
    startFakeRequest()

    const [books, series, everyFavorite] = await Promise.all([
      LibraryUseCase.favoritesBesideSeries(reader, {}),
      LibraryUseCase.lovedSeries(reader, {}),
      LibraryUseCase.rail(reader, {}, 'favorites'),
    ])

    expect(titlesOf(books)).toEqual(['Dune', 'Hypérion'])
    expect(series.map((row) => String(row.name))).toEqual(['Rising'])
    // An installed build that does not ask for the series keeps every book.
    expect(titlesOf(everyFavorite)).toEqual(['Red Rising', 'Dune', 'Hypérion'])
  })

  test('narrows the hearted sagas to the format pill', async () => {
    const frieren = await shelve({ title: 'Frieren', days: 0, format: 'manga', saga: 'Frieren' })
    const rising = await shelve({ title: 'Red Rising', days: 1, saga: 'Rising' })
    await heartSagaOf(frieren)
    await heartSagaOf(rising)

    const series = await LibraryUseCase.lovedSeries(reader, { format: 'manga' })

    expect(series.map((row) => String(row.name))).toEqual(['Frieren'])
  })

  test('pages through the hearted books beside the hearted sagas', async () => {
    const rising = await shelve({ title: 'Red Rising', days: 0, status: 'read', saga: 'Rising' })
    const dune = await shelve({ title: 'Dune', days: 1, status: 'read' })
    const silo = await shelve({ title: 'Silo', days: 2, status: 'read' })
    for (const book of [rising, dune, silo]) await BookCommand.setFavorite(reader, book.id, true)
    await heartSagaOf(rising)
    startFakeRequest()

    const view = { favorite: true, excludeLovedSeries: true }
    const first = await BookQuery.libraryPage(reader, { limit: 1 }, view)
    const next = await BookQuery.libraryPage(reader, { limit: 1, after: first.books[0]?.id }, view)

    expect(titlesOf(first.books)).toEqual(['Dune'])
    expect(first.hasMore).toBe(true)
    expect(titlesOf(next.books)).toEqual(['Silo'])
    expect(next.hasMore).toBe(false)
  })
})

// "Coups de cœur" is what the reader loved: a heart, four stars or more, or —
// on a volume they left unrated — the heart or the four stars of its saga.
describe('"Coups de cœur" holds every book the reader loved', () => {
  const lovedLibrary = async () => {
    const hearted = await shelve({ title: 'Dune', days: 0, status: 'read' })
    await BookCommand.setFavorite(reader, hearted.id, true)
    const fourStars = await shelve({ title: 'Silo', days: 1, status: 'read' })
    await BookCommand.rate(reader, fourStars.id, StarRating(4))
    const threeStars = await shelve({ title: 'Ubik', days: 2, status: 'read' })
    await BookCommand.rate(reader, threeStars.id, StarRating(3))
    const inherited = await shelve({ title: 'Red Rising', days: 3, saga: 'Rising' })
    if (inherited.series)
      await SeriesOpinionCommand.setFavorite(reader, inherited.series.saga, true)
    const ratedLow = await shelve({ title: 'Golden Son', days: 4, saga: 'Rising' })
    await BookCommand.rate(reader, ratedLow.id, StarRating(2))
    const fromStars = await shelve({ title: 'Hypérion', days: 5, saga: 'Cantos' })
    if (fromStars.series)
      await SeriesOpinionCommand.rate(reader, fromStars.series.saga, StarRating(4))
    const fromFewStars = await shelve({ title: 'Fondation', days: 6, saga: 'Fondation' })
    if (fromFewStars.series)
      await SeriesOpinionCommand.rate(reader, fromFewStars.series.saga, StarRating(3))
    await shelve({ title: 'Le Nom du vent', days: 7 })
    startFakeRequest()
  }
  const loved = ['Dune', 'Silo', 'Red Rising', 'Hypérion']

  test('in the rail', async () => {
    await lovedLibrary()

    expect(titlesOf(await LibraryUseCase.rail(reader, {}, 'favorites'))).toEqual(loved)
  })

  test('on the page, a page at a time', async () => {
    await lovedLibrary()

    const view = { favorite: true }
    const first = await BookQuery.libraryPage(reader, { limit: 3 }, view)
    const next = await BookQuery.libraryPage(reader, { limit: 3, after: first.books[2]?.id }, view)

    expect(titlesOf(first.books)).toEqual(loved.slice(0, 3))
    expect(first.hasMore).toBe(true)
    expect(titlesOf(next.books)).toEqual(loved.slice(3))
    expect(next.hasMore).toBe(false)
  })
})
