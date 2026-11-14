import { describe, expect, test } from 'bun:test'
import {
  HEARTS_VERSION,
  heartCountOf,
  heartsAreFresh,
  sharedHeartsOf,
} from '~/domain/analytics/business-rules'
import { BookId, StarRating } from '~/domain/book/primitives'
import type { Book } from '~/domain/book/types'
import { SeriesName, seriesIdOf, VolumeNumber } from '~/domain/series/primitives'
import type { SagaKey } from '~/domain/series/types'
import type { SeriesOpinion } from '~/domain/series-opinion/types'
import { AuthorName, BookTitle } from '~/domain/shared/primitives'
import type { UserId } from '~/domain/shared/types'

const owner = 'owner' as UserId
const dune = 'dune--frank-herbert' as SagaKey
const day = (date: string) => new Date(`${date}T10:00:00Z`)

const book = (id: string, fields: Partial<Book> = {}): Book => ({
  id: BookId(id),
  userId: owner,
  title: BookTitle(id),
  authors: [AuthorName('Frank Herbert')],
  format: 'book',
  media: ['print'],
  subgenres: [],
  narrators: [],
  status: 'read',
  hidden: false,
  addedAt: day('2026-01-01'),
  ...fields,
})

const volume = (id: string, number: number, fields: Partial<Book> = {}) =>
  book(id, {
    language: 'fr',
    series: {
      id: seriesIdOf(dune, 'fr'),
      saga: dune,
      name: SeriesName('Dune'),
      volume: VolumeNumber(number),
      kind: 'main',
    },
    ...fields,
  })

const hearted = (saga: SagaKey, fields: Partial<SeriesOpinion> = {}): SeriesOpinion => ({
  userId: owner,
  seriesId: saga,
  favorite: true,
  ...fields,
})

const ids = (books: readonly Book[]) => books.map((entry) => String(entry.id))

describe('what the friends’ feeds keep of a shelf', () => {
  test('keeps the books hearted and every volume shared of a saga hearted, in library order', () => {
    const shared = sharedHeartsOf(
      owner,
      [
        book('loved', { favorite: true, favoritedAt: day('2026-10-01') }),
        volume('dune-2', 2),
        book('plain'),
        volume('dune-1', 1),
        volume('dune-3', 3, { hidden: true }),
        book('secret', { favorite: true, hidden: true }),
      ],
      [hearted(dune, { favoritedAt: day('2026-10-02'), rating: StarRating(4) })],
    )

    expect(ids(shared.books)).toEqual(['loved', 'dune-2', 'dune-1'])
    expect(shared.favoriteSagas).toEqual([{ saga: dune, favoritedAt: day('2026-10-02') }])
    expect(shared.sagaRatings).toEqual([{ saga: dune, rating: StarRating(4) }])
    expect(shared.truncated).toBeUndefined()
  })

  test('leaves out a saga only rated, and its volumes', () => {
    const shared = sharedHeartsOf(
      owner,
      [volume('dune-1', 1)],
      [{ userId: owner, seriesId: dune, rating: StarRating(5) }],
    )

    expect(shared).toEqual({ userId: owner, books: [], favoriteSagas: [], sagaRatings: [] })
  })

  // A saga goes with every volume or not at all: a tile drawn from part of
  // them would miscount them.
  test('keeps the newest hearts only when asked to, a saga whole', () => {
    const books = [
      book('old', { favorite: true, favoritedAt: day('2026-01-01') }),
      volume('dune-1', 1),
      volume('dune-2', 2),
      book('new', { favorite: true, favoritedAt: day('2026-10-01') }),
    ]
    const opinions = [hearted(dune, { favoritedAt: day('2026-06-01') })]

    const shared = sharedHeartsOf(owner, books, opinions, 2)

    expect(heartCountOf(books, opinions)).toBe(3)
    expect(ids(shared.books)).toEqual(['dune-1', 'dune-2', 'new'])
    expect(shared.favoriteSagas.map((entry) => entry.saga)).toEqual([dune])
    expect(shared.truncated).toBe(true)
  })

  // An old saga heart is news again once one of its volumes is hearted.
  test('dates a saga by the newest heart among it and its volumes', () => {
    const books = [
      book('middle', { favorite: true, favoritedAt: day('2026-06-01') }),
      volume('dune-1', 1, { favorite: true, favoritedAt: day('2026-10-01') }),
    ]
    const opinions = [hearted(dune, { favoritedAt: day('2026-01-01') })]

    expect(ids(sharedHeartsOf(owner, books, opinions, 1).books)).toEqual(['dune-1'])
  })
})

describe('whether a stored projection of the hearts is fresh', () => {
  const state = { userId: owner, version: HEARTS_VERSION, builtFrom: 3, writes: 3 }

  test('is when no write flagged it since it was built', () => {
    expect(heartsAreFresh(state)).toBe(true)
  })

  test('is not once a write flagged it, even one landing while it was built', () => {
    expect(heartsAreFresh({ ...state, writes: 4 })).toBe(false)
  })

  test('is not when built by an older rule set, or never built', () => {
    expect(heartsAreFresh({ ...state, version: HEARTS_VERSION - 1 })).toBe(false)
    expect(heartsAreFresh({ userId: owner, writes: 1 })).toBe(false)
  })

  test('is when built and never flagged since', () => {
    expect(heartsAreFresh({ userId: owner, version: HEARTS_VERSION, builtFrom: 0 })).toBe(true)
  })
})
