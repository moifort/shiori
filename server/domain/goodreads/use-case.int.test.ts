import { beforeEach, describe, expect, mock, spyOn, test } from 'bun:test'
import type { CoverUrl } from '~/domain/book/types'
import type { UserId } from '~/domain/shared/types'
import {
  type FakeFirestore,
  fakeDb,
  resetFakeFirestore,
  startFakeRequest,
} from '~/test/fake-firestore'
import { GOODREADS_EXPORT } from '~/test/goodreads-export'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { GoodreadsUseCase } = await import('~/domain/goodreads/use-case')
const { BookCommand } = await import('~/domain/book/command')
const { BookQuery } = await import('~/domain/book/query')
const { WishQuery } = await import('~/domain/wish/query')
const { AuthorName, BookTitle } = await import('~/domain/shared/primitives')

const reader = 'reader-1' as UserId
const now = new Date('2026-11-25T10:00:00Z')
let fake: FakeFirestore

beforeEach(() => {
  fake = resetFakeFirestore()
})

const allKeys = async () => {
  const preview = await GoodreadsUseCase.preview(reader, GOODREADS_EXPORT)
  if (typeof preview === 'string') throw new Error(preview)
  return preview.rows.map((row) => row.key)
}

const importAll = async (toRead: 'wishlist' | 'pile' = 'wishlist') =>
  GoodreadsUseCase.importExport(
    reader,
    GOODREADS_EXPORT,
    {
      keys: await allKeys(),
      toRead,
      keepRatings: true,
      keepDates: true,
      keepReviews: true,
      sameBooks: [],
    },
    now,
  )

const byTitle = async (title: string) =>
  (await BookQuery.all(reader)).find((book) => book.title === title)

describe('previewing an export', () => {
  test('reads the library in one query and writes nothing', async () => {
    startFakeRequest()
    const before = { docs: fake.docReads, queries: fake.queryReads }

    const preview = await GoodreadsUseCase.preview(reader, GOODREADS_EXPORT)

    expect(typeof preview).not.toBe('string')
    expect(fake.queryReads - before.queries).toBe(1)
    expect(fake.docReads - before.docs).toBe(0)
    expect(await BookQuery.all(reader)).toEqual([])
  })
})

describe('importing an export', () => {
  test('writes each shelf where it belongs, with its stars, date and review', async () => {
    const outcome = await importAll()

    expect(outcome).toEqual({ imported: 4, completed: 0, wished: 1, pendingCovers: 2 })
    const kings = await byTitle('The Way of Kings')
    expect(kings?.status).toBe('read')
    expect(Number(kings?.rating)).toBe(5)
    expect(String(kings?.note)).toBe('Loved it.\n\nKaladin!')
    expect(kings?.finishedAt).toEqual(new Date(Date.UTC(2024, 4, 12, 12)))
    expect(String(kings?.series?.name)).toBe('The Stormlight Archive')
    expect(kings?.origin).toEqual({ kind: 'goodreads' })
    expect((await byTitle('Hypérion'))?.status).toBe('reading')
    expect((await byTitle('Hypérion'))?.media).toEqual(['digital'])
    expect((await byTitle('Le Problème à trois corps'))?.status).toBe('dropped')
    const wishes = await WishQuery.byUser(reader)
    expect(wishes.map((wish) => wish.title)).toEqual([BookTitle('Fondation')])
  })

  test('puts to-read on the pile when the reader owns those books', async () => {
    await importAll('pile')

    expect((await byTitle('Fondation'))?.status).toBe('to-read')
    expect(await WishQuery.byUser(reader)).toEqual([])
  })

  test('adds nothing the second time the same export runs', async () => {
    await importAll()
    const count = (await BookQuery.all(reader)).length

    const outcome = await importAll()

    expect(outcome).toMatchObject({ imported: 0, completed: 0, wished: 0 })
    expect((await BookQuery.all(reader)).length).toBe(count)
  })

  test('completes a book already held with what it lacks, without a second record', async () => {
    await BookCommand.add(reader, {
      title: BookTitle('Le Nom du vent'),
      authors: [AuthorName('Patrick Rothfuss')],
      language: 'fr',
    })

    const outcome = await importAll()

    expect(outcome).toMatchObject({ imported: 3, completed: 1 })
    const books = (await BookQuery.all(reader)).filter((book) => book.title === 'Le Nom du vent')
    expect(books).toHaveLength(1)
    expect(Number(books[0].rating)).toBe(4)
    expect(books[0].status).toBe('read')
  })

  test('leaves out the rows the reader unticked', async () => {
    const keys = await allKeys()
    await GoodreadsUseCase.importExport(
      reader,
      GOODREADS_EXPORT,
      {
        keys: keys.slice(0, 1),
        toRead: 'wishlist',
        keepRatings: true,
        keepDates: true,
        keepReviews: true,
        sameBooks: [],
      },
      now,
    )

    expect((await BookQuery.all(reader)).map((book) => book.title)).toEqual([
      BookTitle('The Way of Kings'),
    ])
  })
})

describe('seeking the covers after an import', () => {
  test('writes the covers a free source has, and forgets the books it looked for', async () => {
    const cover = 'https://covers.example/kings.jpg' as CoverUrl
    const lookup = spyOn(BookQuery, 'publishedCoverOf').mockImplementation(async () => cover)
    await importAll()

    const pass = await GoodreadsUseCase.seekCovers(reader, now)

    expect(pass).toEqual({ remaining: 0, found: 2 })
    expect((await byTitle('The Way of Kings'))?.publishedCoverUrl).toBe(cover)
    expect(await GoodreadsUseCase.seekCovers(reader, now)).toEqual({ remaining: 0, found: 0 })
    lookup.mockRestore()
  })

  test('counts a book no source has as one keeping its stand-in', async () => {
    const lookup = spyOn(BookQuery, 'publishedCoverOf').mockImplementation(async () => undefined)
    await importAll()

    await GoodreadsUseCase.seekCovers(reader, now)

    expect((await GoodreadsUseCase.lastImport(reader))?.withoutCover).toBe(2)
    lookup.mockRestore()
  })
})
