import { describe, expect, test } from 'bun:test'
import { Subgenre } from '~/domain/book/primitives'
import {
  coverVolumeOf,
  favoritesOutsideSagas,
  lastActivityOf,
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

describe('coverVolumeOf', () => {
  const volume = (
    title: string,
    number: number | undefined,
    kind: 'main' | 'novella',
    cover: boolean,
  ) => ({
    title,
    series: {
      id: SeriesId('dune--frank-herbert'),
      name: SeriesName('Dune'),
      volume: number === undefined ? undefined : VolumeNumber(number),
      kind,
    },
    publishedCoverUrl: cover ? ('https://covers.example/x.jpg' as never) : undefined,
    coverPath: undefined,
  })

  test('takes the first main volume that has a cover, whatever order the shelf holds them in', () => {
    const volumes = [
      volume('Les Enfants de Dune', 3, 'main', true),
      volume('Dune', 1, 'main', false),
      volume('Une nouvelle', 1, 'novella', true),
      volume('Le Messie de Dune', 2, 'main', true),
    ]

    expect(coverVolumeOf(volumes)?.title).toBe('Le Messie de Dune')
  })

  test('says nothing for a saga none of whose volumes has a cover', () => {
    expect(coverVolumeOf([volume('Dune', 1, 'main', false)])).toBeUndefined()
  })
})
