import { describe, expect, test } from 'bun:test'
import type { Book, BookId, StarRating } from '~/domain/book/types'
import type { SeriesId, SeriesName } from '~/domain/series/types'
import type { SeriesOpinion } from '~/domain/series-opinion/types'
import type { AuthorName, BookTitle, UserId } from '~/domain/shared/types'
import {
  isHeld,
  MAX_DIGEST_LINES,
  monthOf,
  readerProfileOf,
  referencesOf,
  shouldGenerate,
  shownOf,
  tasteDigestOf,
} from './business-rules'
import type { Dismissal, Suggestion } from './types'

const reader = 'reader' as UserId
let made = 0

/** Loose on purpose: a test writes `rating: 5`, the brand is the domain's. */
type Loose<T> = { [K in keyof T]?: unknown }

const book = (title: string, author: string, extra: Loose<Book> = {}): Book => {
  made += 1
  return {
    id: `book-${made}` as BookId,
    userId: reader,
    title: title as BookTitle,
    authors: [author as AuthorName],
    format: 'book',
    media: ['print'],
    subgenres: [],
    narrators: [],
    status: 'read',
    hidden: false,
    addedAt: new Date('2026-01-01'),
    ...extra,
  } as Book
}

const volume = (title: string, saga: string, number: number, extra: Loose<Book> = {}) =>
  book(title, 'Robin Hobb', {
    series: {
      id: `saga-${saga}` as SeriesId,
      name: saga as SeriesName,
      volume: number as never,
      kind: 'main',
    },
    ...extra,
  })

const opinion = (saga: string, extra: Loose<SeriesOpinion>): SeriesOpinion =>
  ({
    userId: reader,
    seriesId: `saga-${saga}` as SeriesId,
    ...extra,
  }) as SeriesOpinion

const suggestion = (
  title: string,
  author: string,
  extra: Partial<Suggestion> = {},
): Suggestion => ({
  key: `${title}--${author}`,
  title: title as BookTitle,
  originalTitle: title as BookTitle,
  authors: [author as AuthorName],
  language: 'en',
  kind: 'novel',
  reason: 'Parce que.',
  short: 'comme X',
  references: [],
  ...extra,
})

describe('monthOf', () => {
  test('is the UTC year and month', () => {
    expect(monthOf(new Date('2026-10-31T23:30:00Z'))).toBe('2026-10')
  })
})

describe('shouldGenerate', () => {
  const now = new Date('2026-10-15T09:00:00Z')
  const queue = (month: string, generatedAt: string, language: 'fr' | 'en' = 'fr') => ({
    month,
    generatedAt: new Date(generatedAt),
    language,
  })

  test('asks when there is no selection yet', () => {
    expect(shouldGenerate(undefined, now, 'fr')).toBe(true)
  })

  test('asks in a new month', () => {
    expect(shouldGenerate(queue('2026-09', '2026-09-30T09:00:00Z'), now, 'fr')).toBe(true)
  })

  test('asks when the app’s language is not the selection’s', () => {
    expect(shouldGenerate(queue('2026-10', '2026-10-02T09:00:00Z'), now, 'en')).toBe(true)
  })

  test('never refills a month that has its selection', () => {
    expect(shouldGenerate(queue('2026-10', '2026-10-02T09:00:00Z'), now, 'fr')).toBe(false)
  })

  test('never asks twice the same day', () => {
    expect(shouldGenerate(queue('2026-09', '2026-10-15T01:00:00Z'), now, 'en')).toBe(false)
  })
})

describe('tasteDigestOf', () => {
  test('ranks a book by its own heart or stars, best tier first', () => {
    const digest = tasteDigestOf(
      [
        book('Ravage', 'René Barjavel', { rating: 4 }),
        book('Shibumi', 'Trevanian', { rating: 5, favorite: true }),
        book('Ubik', 'Philip K. Dick', { rating: 5 }),
        book('Tau Zero', 'Poul Anderson', { rating: 3 }),
        book('Endymion', 'Dan Simmons', { rating: 2 }),
        book('Sans note', 'Personne'),
      ],
      [],
      [],
    )
    const order = [
      '♥',
      '« Shibumi »',
      '★★★★★',
      '« Ubik »',
      '★★★★ 4',
      '« Ravage »',
      '★★★ 3',
      '« Tau Zero »',
      'Déçu',
      '« Endymion »',
    ]
    let at = -1
    for (const marker of order) {
      const found = digest.indexOf(marker, at + 1)
      expect(found).toBeGreaterThan(at)
      at = found
    }
    expect(digest).not.toContain('Sans note')
  })

  test('lists a saga rated as a whole apart, counting the volumes that borrow its rank', () => {
    const digest = tasteDigestOf(
      [
        volume('Apprentissage', 'Assassin Royal', 1),
        volume('Poison', 'Assassin Royal', 2, { rating: 5, favorite: true }),
      ],
      [opinion('Assassin Royal', { favorite: true, rating: 5 })],
      [],
    )
    expect(digest).toContain('Et ces séries, notées dans leur ensemble :')
    expect(digest).toContain(
      '« Assassin Royal » — Robin Hobb · 2 tome(s) lu(s) (dont 1 sans note propre)',
    )
    expect(digest).not.toContain('« Poison »')
  })

  test('keeps a volume ranked apart from its saga on its own line', () => {
    const digest = tasteDigestOf(
      [volume('Hypérion', 'Hypérion', 1), volume('Endymion', 'Hypérion', 3, { rating: 2 })],
      [opinion('Hypérion', { favorite: true })],
      [],
    )
    expect(digest).toContain('## ★–★★ Déçu\n- « Endymion » — Robin Hobb (tome 3 de Hypérion)')
  })

  test('says what was dropped, books and sagas, and the latest dismissals', () => {
    const digest = tasteDigestOf(
      [
        book('Ulysse', 'James Joyce', { status: 'dropped' }),
        volume('Tome 1', 'Expanse', 1, { status: 'dropped' }),
      ],
      [],
      [
        {
          userId: reader,
          key: 'old',
          title: 'Vieux' as BookTitle,
          authors: ['A' as AuthorName],
          dismissedAt: new Date('2026-01-01'),
        },
        {
          userId: reader,
          key: 'new',
          title: 'Neuf' as BookTitle,
          authors: ['B' as AuthorName],
          dismissedAt: new Date('2026-09-01'),
        },
      ] satisfies Dismissal[],
    )
    expect(digest).toContain(
      '## ✗ Abandonnés\n- « Ulysse » — James Joyce\n- « Expanse » — Robin Hobb (série abandonnée en cours de route)',
    )
    expect(digest.indexOf('Neuf')).toBeLessThan(digest.indexOf('Vieux'))
  })

  test('reads at most so many lines, the best ranked kept', () => {
    const books = Array.from({ length: MAX_DIGEST_LINES + 50 }, (_, index) =>
      book(`Livre ${index}`, 'Auteur', { rating: index < 10 ? 5 : 3 }),
    )
    const digest = tasteDigestOf(books, [], [])
    expect(digest.split('\n').filter((line) => line.startsWith('- ')).length).toBe(MAX_DIGEST_LINES)
    expect(digest).toContain('« Livre 0 »')
  })
})

describe('readerProfileOf', () => {
  test('gives each format and language its share, the commonest first', () => {
    const profile = readerProfileOf([
      { format: 'audiobook', language: 'fr' },
      { format: 'audiobook', language: 'fr' },
      { format: 'book', language: 'en' },
      { format: 'audiobook' },
    ])
    expect(profile.formats).toEqual([
      { value: 'audiobook', share: 0.75 },
      { value: 'book', share: 0.25 },
    ])
    expect(profile.languages[0]).toEqual({ value: 'fr', share: 0.75 })
  })
})

describe('isHeld and shownOf', () => {
  const shelf = [book('La Stratégie Ender', 'Orson Scott Card'), book('Dune', 'Frank Herbert')]

  test('holds a book under its title or original title, by an author of the same surname', () => {
    expect(
      isHeld(
        suggestion('Ender’s Game', 'O. S. Card', { title: 'La Stratégie Ender' as BookTitle }),
        shelf,
      ),
    ).toBe(true)
    expect(isHeld(suggestion('Dune', 'F. Herbert'), shelf)).toBe(true)
    expect(isHeld(suggestion('Dune', 'Brian Herbert-Smith'), shelf)).toBe(false)
  })

  test('shows what is neither held nor dismissed, in the model’s order', () => {
    const shown = shownOf(
      [
        suggestion('Dune', 'Frank Herbert'),
        suggestion('Silo', 'Hugh Howey'),
        suggestion('Hypérion', 'Dan Simmons'),
      ],
      shelf,
      new Set(['Silo--Hugh Howey']),
    )
    expect(shown.map((kept) => kept.title)).toEqual(['Hypérion' as BookTitle])
  })
})

describe('referencesOf', () => {
  test('matches a book by its title and gives its own rank', () => {
    const shibumi = book('Shibumi', 'Trevanian', { rating: 5, favorite: true })
    expect(referencesOf({ references: ['Shibumi'] }, [shibumi], [])).toEqual([
      {
        bookId: shibumi.id,
        title: 'Shibumi',
        rank: { favorite: true, rating: 5 as StarRating, viaSeries: false },
      },
    ])
  })

  test('matches a saga by its name, its first volume, its rank the saga’s', () => {
    const second = volume('Poison', 'Assassin Royal', 2)
    const first = volume('Apprentissage', 'Assassin Royal', 1)
    const [reference] = referencesOf(
      { references: ['L’Assassin royal'] },
      [second, first],
      [opinion('Assassin Royal', { favorite: true, rating: 5 })],
    )
    expect(reference).toEqual({
      bookId: first.id,
      seriesId: 'saga-Assassin Royal' as SeriesId,
      title: 'Assassin Royal',
      rank: { favorite: true, rating: 5 as StarRating, viaSeries: true },
    })
  })

  test('lends a volume with no rank of its own its saga’s, and the best volume’s when the saga has none', () => {
    const unrated = volume('Apprentissage', 'Assassin Royal', 1)
    const rated = volume('Poison', 'Assassin Royal', 2, { rating: 4 })
    expect(
      referencesOf(
        { references: ['Apprentissage'] },
        [unrated],
        [opinion('Assassin Royal', { rating: 5 })],
      )[0]?.rank,
    ).toEqual({
      favorite: false,
      rating: 5 as StarRating,
      viaSeries: true,
    })
    expect(referencesOf({ references: ['Assassin Royal'] }, [unrated, rated], [])[0]?.rank).toEqual(
      {
        favorite: false,
        rating: 4 as StarRating,
        viaSeries: false,
      },
    )
  })

  test('leaves out a title matching nothing, and a book cited twice', () => {
    const shibumi = book('Shibumi', 'Trevanian', { rating: 5 })
    expect(
      referencesOf({ references: ['Inconnu', 'Shibumi', 'shibumi', ''] }, [shibumi], []),
    ).toHaveLength(1)
  })
})
