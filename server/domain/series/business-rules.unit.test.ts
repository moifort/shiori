import { describe, expect, test } from 'bun:test'
import {
  followedSagasOf,
  inCatalogueOrder,
  splitBySpine,
  stateOf,
} from '~/domain/series/business-rules'
import { SeriesId, SeriesName, VolumeNumber } from '~/domain/series/primitives'
import type { Series, Volume } from '~/domain/series/types'
import { AuthorName, BookTitle, Year } from '~/domain/shared/primitives'

const THIS_YEAR = Year(2026)

const volume = (partial: Omit<Partial<Volume>, 'title'> & { title: string }): Volume => ({
  title: BookTitle(partial.title),
  kind: partial.kind ?? 'main',
  number: partial.number,
  publishedIn: partial.publishedIn,
})

const saga = (volumes: Volume[]): Series => ({
  id: SeriesId('saga--author'),
  name: SeriesName('Saga'),
  author: AuthorName('Author'),
  volumes,
  catalogedAt: new Date('2026-01-01'),
})

describe('stateOf', () => {
  test('is complete once every published volume has been read', () => {
    const series = saga([
      volume({ title: 'One', number: VolumeNumber(1), publishedIn: Year(2020) }),
      volume({ title: 'Two', number: VolumeNumber(2), publishedIn: Year(2022) }),
    ])
    expect(stateOf(series, new Set([1, 2]), THIS_YEAR)).toBe('complete')
  })

  test('stays in progress while a published volume is unread', () => {
    const series = saga([
      volume({ title: 'One', number: VolumeNumber(1), publishedIn: Year(2020) }),
      volume({ title: 'Two', number: VolumeNumber(2), publishedIn: Year(2022) }),
    ])
    expect(stateOf(series, new Set([1]), THIS_YEAR)).toBe('in-progress')
  })

  // A reader who is up to date on a running saga has finished it as far as the
  // world is concerned. Holding the saga open because book 3 is announced for
  // next year would tell them they are behind on a book nobody can read.
  test('an announced but unpublished volume does not hold the saga open', () => {
    const series = saga([
      volume({ title: 'One', number: VolumeNumber(1), publishedIn: Year(2020) }),
      volume({ title: 'Three', number: VolumeNumber(3), publishedIn: Year(2030) }),
    ])
    expect(stateOf(series, new Set([1]), THIS_YEAR)).toBe('complete')
  })

  // "Complete" would read as an achievement where nothing was achieved.
  test('a saga with nothing published yet is in progress, not complete', () => {
    const series = saga([
      volume({ title: 'Soon', number: VolumeNumber(1), publishedIn: Year(2030) }),
    ])
    expect(stateOf(series, new Set(), THIS_YEAR)).toBe('in-progress')
  })
})

describe('inCatalogueOrder', () => {
  test('puts the numbered spine first, ascending, then what orbits it', () => {
    const ordered = inCatalogueOrder([
      volume({ title: 'Companion', kind: 'companion' }),
      volume({ title: 'Two', number: VolumeNumber(2) }),
      volume({ title: 'Prequel', kind: 'prequel' }),
      volume({ title: 'One', number: VolumeNumber(1) }),
    ])
    expect(ordered.map((entry) => String(entry.title))).toEqual([
      'One',
      'Two',
      'Prequel',
      'Companion',
    ])
  })

  test('falls back to title so two unnumbered entries keep a stable order', () => {
    const ordered = inCatalogueOrder([
      volume({ title: 'Beta', kind: 'novella' }),
      volume({ title: 'Alpha', kind: 'novella' }),
    ])
    expect(ordered.map((entry) => String(entry.title))).toEqual(['Alpha', 'Beta'])
  })
})

describe('splitBySpine', () => {
  test('separates the main story from its related works', () => {
    const { spine, relatedWorks } = splitBySpine(
      saga([
        volume({ title: 'One', number: VolumeNumber(1) }),
        volume({ title: 'Side story', kind: 'spin-off' }),
        volume({ title: 'Atlas', kind: 'companion' }),
      ]),
    )
    expect(spine.map((entry) => String(entry.title))).toEqual(['One'])
    expect(relatedWorks.map((entry) => String(entry.title))).toEqual(['Side story', 'Atlas'])
  })
})

describe('followedSagasOf', () => {
  const volumeOf = (title: string, series?: { id: string; name: string }) => ({
    title,
    authors: [AuthorName('Frank Herbert')],
    series: series && { id: SeriesId(series.id), name: SeriesName(series.name) },
  })

  const DUNE = { id: 'dune--frank-herbert', name: 'Dune' }

  test('gathers the volumes of one saga under it', () => {
    const sagas = followedSagasOf([volumeOf('Dune', DUNE), volumeOf('Le Messie de Dune', DUNE)])
    expect(sagas).toHaveLength(1)
    expect(sagas[0]?.books.map((book) => book.title)).toEqual(['Dune', 'Le Messie de Dune'])
  })

  // The defect this rule exists to fix: an Audible import and a book added by
  // hand write a membership without ever calling the model, so a reading that
  // started from the catalogue found nothing and the Series tab stayed empty.
  test('follows a saga the catalogue has never heard of', () => {
    expect(followedSagasOf([volumeOf('Dune', DUNE)])[0]?.id).toBe(SeriesId(DUNE.id))
  })

  test('ignores a book that belongs to no saga', () => {
    expect(followedSagasOf([volumeOf('Piranesi')])).toEqual([])
  })

  test('answers alphabetically', () => {
    const sagas = followedSagasOf([
      volumeOf('Dune', { id: 'z', name: 'Zorro' }),
      volumeOf('Dune', DUNE),
    ])
    expect(sagas.map((saga) => saga.name)).toEqual([SeriesName('Dune'), SeriesName('Zorro')])
  })

  // The catalogue carries an author; a saga that has no catalogue has to get one
  // from somewhere, and the volumes the reader owns are the only source there is.
  test('takes the author from the first volume that names one', () => {
    expect(followedSagasOf([volumeOf('Dune', DUNE)])[0]?.author).toBe(AuthorName('Frank Herbert'))
  })
})
