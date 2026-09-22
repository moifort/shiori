import { describe, expect, test } from 'bun:test'
import type { SharedShelf } from '~/domain/analytics/types'
import type { AudibleRelease } from '~/domain/audible/types'
import type { Book, BookId } from '~/domain/book/types'
import {
  alertOf,
  audibleShelvesOf,
  dueReleases,
  friendsFavoritesOf,
  releaseSubjectsOf,
  releasesOf,
  tasteOf,
  unseen,
} from '~/domain/discover/business-rules'
import { suggestionFrom } from '~/domain/discover/parsing'
import { ReleaseDate } from '~/domain/discover/primitives'
import type { Release, ReleaseSubject, ReleaseWatch } from '~/domain/discover/types'
import type { SeriesId, SeriesName } from '~/domain/series/types'
import type { AuthorName, BookTitle, UserId } from '~/domain/shared/types'

const at = (day: string) => new Date(`${day}T12:00:00Z`)
let counter = 0
const book = (fields: Partial<Book>): Book => ({
  id: `book-${counter++}` as BookId,
  userId: 'reader' as UserId,
  title: 'Untitled' as BookTitle,
  authors: [],
  format: 'book',
  subgenres: [],
  narrators: [],
  status: 'to-read',
  hidden: false,
  addedAt: at('2026-01-01'),
  ...fields,
})
const saga = (name: string, volume: number) => ({
  id: `${name.toLowerCase()}--x` as SeriesId,
  name: name as SeriesName,
  volume: volume as never,
  kind: 'main' as const,
})

describe("the reader's taste", () => {
  const library = [
    book({
      title: 'Cradle' as BookTitle,
      authors: ['Will Wight' as AuthorName],
      favorite: true,
      status: 'read',
      genre: 'fantasy',
      finishedAt: at('2026-05-01'),
    }),
    book({
      title: 'Mistborn' as BookTitle,
      authors: ['Brandon Sanderson' as AuthorName],
      rating: 5 as never,
      status: 'read',
      genre: 'fantasy',
      finishedAt: at('2026-04-01'),
    }),
    book({
      title: 'Dune' as BookTitle,
      authors: ['Frank Herbert' as AuthorName],
      rating: 3 as never,
      status: 'read',
      genre: 'science-fiction',
      language: 'en',
    }),
    book({
      title: 'The Way of Kings' as BookTitle,
      authors: ['Brandon Sanderson' as AuthorName],
      status: 'reading',
      genre: 'fantasy',
      language: 'en',
      series: saga('Stormlight', 1),
    }),
    book({ title: 'Abandonné' as BookTitle, status: 'dropped', series: saga('Dropped', 1) }),
  ]
  const taste = tasteOf(library, 'fr')

  test('loves the hearted and the five-star books, most recent first', () => {
    expect(taste.loved.map((b) => b.title)).toEqual(['Cradle', 'Mistborn'] as BookTitle[])
    expect(taste.authors).toEqual(['Will Wight', 'Brandon Sanderson'] as AuthorName[])
  })

  test('leans on the genres of what it reads, fantasy first', () => {
    expect(taste.genres).toEqual(['fantasy', 'science-fiction'])
  })

  test('follows the sagas it has not dropped, and notes the books read in another language', () => {
    expect(taste.sagas.map((s) => s.name)).toEqual(['Stormlight'] as SeriesName[])
    expect(taste.foreignReads.map((b) => b.title)).toContain('Dune' as BookTitle)
  })

  test('watches each saga, each loved author, and one translation per saga', () => {
    const subjects = releaseSubjectsOf(taste)
    expect(subjects.filter((s) => s.kind === 'series')).toHaveLength(1)
    expect(subjects.filter((s) => s.kind === 'author')).toHaveLength(2)
    expect(subjects.flatMap((s) => (s.kind === 'translation' ? [s.title] : [])).sort()).toEqual([
      'Dune',
      'Stormlight',
    ] as BookTitle[])
  })
})

describe('the releases one reader cares about', () => {
  const series: ReleaseSubject = {
    kind: 'series',
    name: 'Stormlight' as SeriesName,
    author: 'Brandon Sanderson' as AuthorName,
  }
  const watch = (releases: ReleaseWatch['releases']): ReleaseWatch => ({
    key: 'k',
    subject: series,
    checkedAt: at('2026-09-01'),
    releases,
  })
  const release = (title: string, date: string, format: 'book' | 'audiobook' = 'book') => ({
    title: title as BookTitle,
    authors: ['Brandon Sanderson' as AuthorName],
    date: ReleaseDate(date),
    format,
  })

  test('keeps what is ahead or recent, drops what is long out and what the reader owns', () => {
    const found = releasesOf(
      [
        {
          subject: series,
          watch: watch([
            release('Tome 6', '2026-10-14'),
            release('Old', '2025-01-01'),
            release('Owned', '2026-11-01'),
          ]),
        },
      ],
      new Set(['owned--brandon-sanderson']),
      '2026-09-22',
      () => 'reason',
    )
    expect(found.map((r) => r.title)).toEqual(['Tome 6'] as BookTitle[])
  })

  test('files a recording of a saga as an Audible release', () => {
    const [found] = releasesOf(
      [{ subject: series, watch: watch([release('Tome 6', '2026-10-14', 'audiobook')]) }],
      new Set(),
      '2026-09-22',
      () => '',
    )
    expect(found?.kind).toBe('audible-release')
  })

  test('keeps a year-only announcement until the year is over', () => {
    const found = releasesOf(
      [{ subject: series, watch: watch([release('Someday', '2026')]) }],
      new Set(),
      '2026-09-22',
      () => '',
    )
    expect(found).toHaveLength(1)
  })
})

describe('the alerts due today', () => {
  const release = (key: string, date: string): Release => ({
    key,
    kind: 'series-volume',
    title: key as BookTitle,
    authors: [],
    format: 'book',
    date: ReleaseDate(date),
    reason: '',
  })

  test('fire on the day, within two weeks after, once', () => {
    const releases = [
      release('today', '2026-09-22'),
      release('late', '2026-09-10'),
      release('stale', '2026-08-01'),
      release('ahead', '2026-09-30'),
      release('month', '2026-09'),
      release('sent', '2026-09-21'),
    ]
    expect(dueReleases(releases, ['sent'], '2026-09-22').map((r) => r.key)).toEqual([
      'today',
      'late',
    ])
  })

  test('speak the reader language', () => {
    const volume = {
      ...release('La Voie des rois', '2026-09-22'),
      series: { name: 'Stormlight' as SeriesName, volume: 6 as never },
    }
    expect(alertOf(volume, 'fr')).toEqual({
      title: 'Nouveau tome',
      body: "La Voie des rois, tome 6 de Stormlight, sort aujourd'hui.",
    })
    expect(alertOf(volume, 'en').title).toBe('New volume')
  })
})

describe('what the tab shows', () => {
  test('leaves out what the reader owns, dismissed, or was proposed twice', () => {
    const items = [{ key: 'a' }, { key: 'b' }, { key: 'a' }, { key: 'c' }]
    expect(unseen(items, new Set(['b']), ['c'])).toEqual([{ key: 'a' }])
  })

  test('gathers the friends who hearted the same book, the most hearted first', () => {
    const favorite = (title: string, id: string) => ({
      id: id as BookId,
      title: title as BookTitle,
      authors: ['A' as AuthorName],
      format: 'book' as const,
    })
    const shelf = (favorites: SharedShelf['favorites']): SharedShelf => ({
      favoriteCount: favorites.length,
      readingCount: 0,
      toReadCount: 0,
      favorites,
    })
    const shelves = new Map<UserId, SharedShelf>([
      ['claire' as UserId, shelf([favorite('Solo', 's1'), favorite('Shared', 'x1')])],
      ['julie' as UserId, shelf([favorite('Shared', 'x2')])],
    ])
    const names = new Map([
      ['claire' as UserId, 'Claire'],
      ['julie' as UserId, 'Julie'],
    ])

    const found = friendsFavoritesOf(shelves, names, new Set(), [])

    expect(found.map((f) => [f.title as string, f.friendNames])).toEqual([
      ['Shared', ['Claire', 'Julie']],
      ['Solo', ['Claire']],
    ])
    expect(found[0]?.bookId).toBe('x1' as BookId)
  })

  test('turns a preordered Audible volume into a release as well as a suggestion', () => {
    const next = {
      asin: 'B0TESTASIN' as never,
      title: 'Cradle 13' as BookTitle,
      authors: ['Will Wight' as AuthorName],
      narrators: [],
      subgenres: [],
      status: 'to-read',
      alreadyInLibrary: false,
      series: saga('Cradle', 13),
      releaseDate: at('2026-11-02'),
    } as unknown as AudibleRelease
    const { suggestions, releases } = audibleShelvesOf([next], 'fr')
    expect(suggestions[0]?.reason).toBe('Tome 13 de Cradle, la suite de ce que vous écoutez')
    expect(releases[0]).toMatchObject({ kind: 'audible-release', date: '2026-11-02' })
  })
})

describe('a model answer', () => {
  test('keeps a good suggestion and drops a hallucinated ISBN on its own', () => {
    const suggestion = suggestionFrom({
      title: 'Dungeon Crawler Carl',
      authors: ['Matt Dinniman'],
      isbn13: '123',
      reason: 'Parce que Cradle.',
      publicRating: 4.62,
      ratingCount: 210000,
    })
    expect(suggestion).toMatchObject({
      key: 'dungeon-crawler-carl--matt-dinniman',
      publicRating: 4.6,
      ratingCount: 210000,
    })
    expect(suggestion?.isbn13).toBeUndefined()
  })

  test('drops a suggestion with no reason or no title', () => {
    expect(suggestionFrom({ title: 'X', authors: [], reason: '' })).toBeUndefined()
    expect(suggestionFrom({ title: '', authors: [], reason: 'r' })).toBeUndefined()
  })

  test('refuses a date that is not on the calendar', () => {
    expect(() => ReleaseDate('2027-02-30')).toThrow()
    expect(ReleaseDate('2027-02')).toBe(ReleaseDate('2027-02'))
  })
})
