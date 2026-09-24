import { describe, expect, test } from 'bun:test'
import { Subgenre } from '~/domain/book/primitives'
import {
  favoritesOutsideSagas,
  friendSagaStateOf,
  inReadingOrder,
  lastActivityOf,
  lastFinishedOf,
  newestFavoritesFirst,
  subgenreOf,
} from '~/domain/friendship/business-rules'
import { SeriesId, SeriesName, VolumeNumber } from '~/domain/series/primitives'

const day = (n: number) => new Date(Date.UTC(2026, 8, n))

describe('lastActivityOf', () => {
  // A listening position moved by the nightly sync is activity too, and it
  // only ever shows as `updatedAt`.
  test('takes the latest of every stamp the record carries', () => {
    expect(
      lastActivityOf({
        addedAt: day(1),
        startedAt: day(3),
        statusChangedAt: day(3),
        updatedAt: day(9),
      }),
    ).toEqual(day(9))
  })

  test('falls back to the day it was added on a record with no other stamp', () => {
    expect(lastActivityOf({ addedAt: day(2) })).toEqual(day(2))
  })
})

describe('friendSagaStateOf', () => {
  test('reads not started, complete or in progress off the volumes on the shelf', () => {
    expect(friendSagaStateOf([{ status: 'to-read' }, { status: 'to-read' }])).toBe('not-started')
    expect(friendSagaStateOf([{ status: 'read' }, { status: 'read' }])).toBe('complete')
    expect(friendSagaStateOf([{ status: 'read' }, { status: 'to-read' }])).toBe('in-progress')
    expect(friendSagaStateOf([{ status: 'reading' }])).toBe('in-progress')
  })
})

describe('lastFinishedOf', () => {
  test('picks the book read with the latest finishing date', () => {
    const books = [
      { title: 'earlier', status: 'read' as const, finishedAt: day(3) },
      { title: 'latest', status: 'read' as const, finishedAt: day(9) },
      { title: 'in progress', status: 'reading' as const },
    ]
    expect(lastFinishedOf(books)?.title).toBe('latest')
  })

  // A book filed as read with no date says nothing about when.
  test('answers nothing when no book read carries its date', () => {
    expect(lastFinishedOf([{ status: 'read' as const }, { status: 'to-read' as const }])).toBe(
      undefined,
    )
  })
})

describe('newestFavoritesFirst', () => {
  test('puts the most recently hearted first', () => {
    const favorites = [
      { title: 'old', addedAt: day(1), favoritedAt: day(2) },
      { title: 'new', addedAt: day(1), favoritedAt: day(8) },
    ]
    expect(newestFavoritesFirst(favorites).map(({ title }) => title)).toEqual(['new', 'old'])
  })

  // A heart given before the date was kept is older than any dated heart.
  test('ranks an undated heart on the book last activity, after a dated one', () => {
    const favorites = [
      { title: 'undated', addedAt: day(1), updatedAt: day(5) },
      { title: 'dated', addedAt: day(1), favoritedAt: day(9) },
      { title: 'older undated', addedAt: day(1), updatedAt: day(3) },
    ]
    expect(newestFavoritesFirst(favorites).map(({ title }) => title)).toEqual([
      'dated',
      'undated',
      'older undated',
    ])
  })
})

describe('favoritesOutsideSagas', () => {
  const dune = SeriesId('dune--frank-herbert')
  const inSaga = (title: string, id: typeof dune) => ({
    title,
    series: { id, name: SeriesName('Saga'), volume: VolumeNumber(1), kind: 'main' as const },
  })

  test('drops a volume already standing for through its hearted saga', () => {
    const favorites = [
      inSaga('Dune', dune),
      inSaga('Hypérion', SeriesId('hyperion--dan-simmons')),
      { title: 'Piranesi', series: undefined },
    ]

    expect(favoritesOutsideSagas(favorites, new Set([dune])).map((book) => book.title)).toEqual([
      'Hypérion',
      'Piranesi',
    ])
  })
})

describe('subgenreOf', () => {
  const tagged = (label: string) => ({ label: Subgenre(label), language: 'fr' as const })

  test('reads the subgenre off a volume of the saga genre', () => {
    const books = [
      { genre: 'fantasy' as const, subgenres: [tagged('Urban fantasy')] },
      { genre: 'science-fiction' as const, subgenres: [tagged('Space opera')] },
    ]

    expect(subgenreOf(books, 'science-fiction')?.label).toBe(Subgenre('Space opera'))
  })

  test('says nothing when no volume of that genre has a subgenre', () => {
    expect(subgenreOf([{ genre: 'fantasy' as const, subgenres: [] }], 'fantasy')).toBeUndefined()
  })
})

describe('inReadingOrder', () => {
  const volume = (title: string, number: number | undefined, kind: 'main' | 'novella') => ({
    title,
    series: {
      id: SeriesId('dune--frank-herbert'),
      name: SeriesName('Dune'),
      volume: number === undefined ? undefined : VolumeNumber(number),
      kind,
    },
  })

  test('puts main volumes first by number, the rest after, whatever order the shelf holds them in', () => {
    const volumes = [
      volume('Les Enfants de Dune', 3, 'main'),
      volume('Une nouvelle', 1, 'novella'),
      volume('Sans numéro', undefined, 'main'),
      volume('Dune', 1, 'main'),
    ]

    expect(inReadingOrder(volumes).map((book) => book.title)).toEqual([
      'Dune',
      'Les Enfants de Dune',
      'Sans numéro',
      'Une nouvelle',
    ])
  })
})
