import { describe, expect, test } from 'bun:test'
import {
  followedSagasOf,
  followedStateOf,
  genreOf,
  inCatalogueOrder,
  inTabOrder,
  progressOf,
  splitBySpine,
  stateOf,
  withoutDuplicateVolumes,
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

describe('progressOf', () => {
  test('counts the read volumes of the published spine', () => {
    const series = saga([
      volume({ title: 'One', number: VolumeNumber(1) }),
      volume({ title: 'Two', number: VolumeNumber(2) }),
      volume({ title: 'Three', number: VolumeNumber(3) }),
    ])
    expect(progressOf(series, new Set([1, 3]), THIS_YEAR)).toEqual({ readCount: 2, totalCount: 3 })
  })

  // A finished spine must read as finished: a novella and an announced volume
  // would otherwise hold the count below the total for years.
  test('leaves related works and announced volumes out of the count', () => {
    const series = saga([
      volume({ title: 'One', number: VolumeNumber(1) }),
      volume({ title: 'Next', number: VolumeNumber(2), publishedIn: Year(2030) }),
      volume({ title: 'Side story', kind: 'novella' }),
    ])
    expect(progressOf(series, new Set([1]), THIS_YEAR)).toEqual({ readCount: 1, totalCount: 1 })
  })

  test('has nothing to measure on a catalogue with no numbered volume', () => {
    expect(progressOf(saga([volume({ title: 'Loose' })]), new Set(), THIS_YEAR)).toBeNull()
  })
})

describe('genreOf', () => {
  test('is the genre most volumes carry', () => {
    expect(
      genreOf([{ genre: 'fantasy' }, { genre: 'science-fiction' }, { genre: 'science-fiction' }]),
    ).toBe('science-fiction')
  })

  test('breaks a tie on the volume met first', () => {
    expect(genreOf([{ genre: 'horror' }, { genre: 'fantasy' }])).toBe('horror')
  })

  test('is unknown when no volume has a genre', () => {
    expect(genreOf([{}, {}])).toBeUndefined()
  })
})

describe('followedStateOf', () => {
  const series = saga([volume({ title: 'One', number: VolumeNumber(1), publishedIn: Year(2020) })])

  test('is not started while no volume has been opened, catalogue or not', () => {
    expect(followedStateOf(['to-read'], series, new Set(), THIS_YEAR)).toBe('not-started')
    expect(followedStateOf(['to-read', 'to-read'], null, new Set(), THIS_YEAR)).toBe('not-started')
  })

  test('lets the catalogue decide once a volume has been opened', () => {
    expect(followedStateOf(['read'], series, new Set([1]), THIS_YEAR)).toBe('complete')
    expect(followedStateOf(['reading'], series, new Set(), THIS_YEAR)).toBe('in-progress')
  })

  test('is in progress without a catalogue while an owned volume is unread', () => {
    expect(followedStateOf(['read', 'to-read'], null, new Set([1]), THIS_YEAR)).toBe('in-progress')
  })

  test('is unknown without a catalogue once every owned volume is read', () => {
    expect(followedStateOf(['read'], null, new Set([1]), THIS_YEAR)).toBeNull()
  })
})

describe('inTabOrder', () => {
  const at = (day: number) => new Date(`2026-09-${String(day).padStart(2, '0')}`)

  test('groups by genre in the closed list order, no genre last', () => {
    const sagas = [
      { name: 'A', state: null, lastStatusChangeAt: at(1) },
      { name: 'B', genre: 'science-fiction' as const, state: null, lastStatusChangeAt: at(1) },
      { name: 'C', genre: 'fantasy' as const, state: null, lastStatusChangeAt: at(1) },
      { name: 'D', genre: 'science-fiction' as const, state: null, lastStatusChangeAt: at(1) },
    ]
    expect(inTabOrder(sagas).map((saga) => saga.name)).toEqual(['C', 'B', 'D', 'A'])
  })

  test('orders a genre by state, then by the latest status change first', () => {
    const sagas = [
      { name: 'untouched', state: 'not-started' as const, lastStatusChangeAt: at(20) },
      { name: 'unknown', state: null, lastStatusChangeAt: at(19) },
      { name: 'done', state: 'complete' as const, lastStatusChangeAt: at(18) },
      { name: 'older', state: 'in-progress' as const, lastStatusChangeAt: at(2) },
      { name: 'newer', state: 'in-progress' as const, lastStatusChangeAt: at(10) },
    ]
    expect(inTabOrder(sagas).map((saga) => saga.name)).toEqual([
      'newer',
      'older',
      'done',
      'unknown',
      'untouched',
    ])
  })
})

describe('withoutDuplicateVolumes', () => {
  // Blood Song came back with Tome 1 and Tome 2 twice each, one per edition.
  test('keeps one main volume per number, the first one given', () => {
    const folded = withoutDuplicateVolumes([
      volume({ title: 'La Voix du sang', number: VolumeNumber(1) }),
      volume({ title: 'Blood Song', number: VolumeNumber(1) }),
      volume({ title: 'Le Seigneur de la tour', number: VolumeNumber(2) }),
      volume({ title: 'Tower Lord', number: VolumeNumber(2) }),
    ])
    expect(folded.map((entry) => String(entry.title))).toEqual([
      'La Voix du sang',
      'Le Seigneur de la tour',
    ])
  })

  test('keeps one entry per kind and title off the numbering', () => {
    const folded = withoutDuplicateVolumes([
      volume({ title: 'Le Loup', kind: 'novella' }),
      volume({ title: 'le loup', kind: 'novella' }),
      volume({ title: 'Le Loup', kind: 'companion' }),
    ])
    expect(folded.map((entry) => entry.kind)).toEqual(['novella', 'companion'])
  })
})
