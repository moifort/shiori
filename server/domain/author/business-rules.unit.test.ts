import { describe, expect, test } from 'bun:test'
import {
  featuredSagaOf,
  inAuthorOrder,
  matchingAuthorFilter,
  shelvedAuthorsOf,
} from '~/domain/author/business-rules'
import { authorKeyOf } from '~/domain/author/primitives'
import type { ReadingStatus } from '~/domain/book/types'
import { SeriesId, SeriesName } from '~/domain/series/primitives'
import type { SeriesState } from '~/domain/series/types'
import type { FollowedSeries } from '~/domain/series/use-case'
import { AuthorName, Count } from '~/domain/shared/primitives'

const day = (date: number) => new Date(Date.UTC(2026, 8, date))

const book = (
  title: string,
  authors: string[],
  options: { series?: string; rating?: number; favorite?: boolean; on?: number } = {},
) => ({
  title,
  authors: authors.map(AuthorName),
  series: options.series ? { id: SeriesId(options.series) } : undefined,
  rating: options.rating,
  favorite: options.favorite,
  addedAt: day(options.on ?? 1),
})

describe('authorKeyOf', () => {
  test('folds diacritics and case, so two spellings of one name meet', () => {
    expect(authorKeyOf('Émile Zola')).toBe(authorKeyOf('emile zola'))
  })

  test('keeps a name the slug has nothing of, rather than an empty key', () => {
    expect(String(authorKeyOf('村上春樹'))).toBe('村上春樹')
    expect(authorKeyOf('村上春樹')).not.toBe(authorKeyOf('東野圭吾'))
  })
})

describe('shelvedAuthorsOf', () => {
  test('puts a book written by two authors on both', () => {
    const authors = shelvedAuthorsOf([book('Good Omens', ['Terry Pratchett', 'Neil Gaiman'])], [])

    expect(authors.map((author) => String(author.name))).toEqual(['Terry Pratchett', 'Neil Gaiman'])
    expect(authors.every((author) => author.books.length === 1)).toBe(true)
  })

  test('orders an author’s books newest shelved first', () => {
    const [author] = shelvedAuthorsOf(
      [book('Old', ['A'], { on: 1 }), book('New', ['A'], { on: 9 }), book('Mid', ['A'], { on: 5 })],
      [],
    )

    expect(author?.books.map((held) => held.title)).toEqual(['New', 'Mid', 'Old'])
  })

  test('names an author by the spelling most of their books use', () => {
    const [author] = shelvedAuthorsOf(
      [
        book('One', ['Emile Zola'], { on: 9 }),
        book('Two', ['Émile Zola'], { on: 2 }),
        book('Three', ['Émile Zola'], { on: 1 }),
      ],
      [],
    )

    expect(author?.name).toBe(AuthorName('Émile Zola'))
    expect(author?.books).toHaveLength(3)
  })

  test('counts hearted books and hearted sagas, and averages every star', () => {
    const [author] = shelvedAuthorsOf(
      [
        book('Dune', ['Frank Herbert'], { series: 'dune', rating: 5, favorite: true }),
        book('Dune Messiah', ['Frank Herbert'], { series: 'dune', rating: 3 }),
        book('The Dosadi Experiment', ['Frank Herbert']),
      ],
      [{ seriesId: SeriesId('dune'), rating: 4, favorite: true }],
    )

    expect(author?.favoriteCount).toBe(Count(2))
    expect(author?.averageRating).toBe(4)
    expect(author?.seriesIds).toEqual([SeriesId('dune')])
  })

  test('leaves the mean out when nothing is rated', () => {
    const [author] = shelvedAuthorsOf([book('Unread', ['A'])], [])

    expect(author?.averageRating).toBeUndefined()
  })
})

describe('inAuthorOrder', () => {
  const author = (name: string, favoriteCount: number, averageRating?: number, books = 1) => ({
    key: authorKeyOf(name),
    name: AuthorName(name),
    books: Array.from({ length: books }),
    seriesIds: [],
    favoriteCount: Count(favoriteCount),
    averageRating,
  })

  test('ranks hearts first, then stars, then books held, then name', () => {
    const ranked = inAuthorOrder([
      author('Zed', 0, 5),
      author('Many books', 0, 3, 9),
      author('Hearted', 1, 2),
      author('Few books', 0, 3, 1),
      author('Alpha', 0, 5),
      author('Unrated', 0),
    ])

    expect(ranked.map((entry) => String(entry.name))).toEqual([
      'Hearted',
      'Alpha',
      'Zed',
      'Many books',
      'Few books',
      'Unrated',
    ])
  })

  test('keeps only the authors with a heart in the favourites', () => {
    const kept = matchingAuthorFilter([author('Loved', 2), author('Read', 0)], { favorite: true })

    expect(kept.map((entry) => String(entry.name))).toEqual(['Loved'])
  })
})

describe('featuredSagaOf', () => {
  const saga = (
    name: string,
    state: SeriesState | null,
    shelvedOn: number,
    options: {
      progress?: { readCount: number; totalCount: number }
      statuses?: ReadingStatus[]
    } = {},
  ) =>
    ({
      id: SeriesId(name.toLowerCase()),
      name: SeriesName(name),
      state,
      shelvedAt: day(shelvedOn),
      progress: options.progress ?? null,
      books: (options.statuses ?? []).map((status) => ({ status })),
    }) as unknown as FollowedSeries

  test('shows the saga in progress shelved last, over any finished one', () => {
    const featured = featuredSagaOf([
      saga('Done', 'complete', 20),
      saga('Older', 'in-progress', 1),
      saga('Newer', 'in-progress', 10, { progress: { readCount: 2, totalCount: 5 } }),
    ])

    expect(featured?.series.name).toBe(SeriesName('Newer'))
    expect(featured).toMatchObject({ readCount: 2, totalCount: 5 })
  })

  test('falls back to the finished saga, a saga of unknown state among them', () => {
    const featured = featuredSagaOf([
      saga('Pile', 'not-started', 30),
      saga('Aside', 'unfollowed', 30),
      saga('Unknown', null, 12, { statuses: ['read', 'read'] }),
      saga('Done', 'complete', 3),
    ])

    expect(featured?.series.name).toBe(SeriesName('Unknown'))
    expect(featured).toMatchObject({ readCount: 2, totalCount: 2 })
  })

  test('shows nothing when no saga is in progress or finished', () => {
    expect(featuredSagaOf([saga('Pile', 'not-started', 1)])).toBeNull()
    expect(featuredSagaOf([])).toBeNull()
  })
})
