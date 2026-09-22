import { describe, expect, test } from 'bun:test'
import {
  cataloguesOf,
  followedSagasOf,
  followedStateOf,
  genreOf,
  inCatalogueOrder,
  inTabOrder,
  progressOf,
  provisionalCatalogueOf,
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

  // The same yardstick as the ring beside it: a saga whose four main volumes
  // are read was labelled "in progress" on an unread novella, next to a ring
  // that said four out of four.
  test('is complete once the main spine is read, whatever the related works', () => {
    const series = saga([
      volume({ title: 'One', number: VolumeNumber(1) }),
      volume({ title: 'Two', number: VolumeNumber(2) }),
      volume({ title: 'Side story', kind: 'novella' }),
      volume({ title: 'Prequel', number: VolumeNumber(3), kind: 'prequel' }),
    ])
    expect(stateOf(series, new Set([1, 2]), THIS_YEAR)).toBe('complete')
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

  // A saga the reader stopped following is out of every other state, whatever
  // their volumes say: it is neither in progress nor done, it is set aside.
  test('is unfollowed once the reader stopped following it, whatever was read', () => {
    expect(followedStateOf(['reading'], series, new Set(), THIS_YEAR, true)).toBe('unfollowed')
    expect(followedStateOf(['read'], series, new Set([1]), THIS_YEAR, true)).toBe('unfollowed')
    expect(followedStateOf(['to-read'], null, new Set(), THIS_YEAR, true)).toBe('unfollowed')
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

  // Neither genre nor state sections the tab any more: one timeline of sagas.
  test('puts the saga shelved most recently first, whatever its genre or state', () => {
    const sagas = [
      {
        name: 'untouched',
        genre: 'fantasy' as const,
        state: 'not-started' as const,
        shelvedAt: at(20),
      },
      { name: 'older', state: 'in-progress' as const, shelvedAt: at(2) },
      { name: 'done', genre: 'essay' as const, state: 'complete' as const, shelvedAt: at(18) },
      { name: 'newer', state: 'in-progress' as const, shelvedAt: at(10) },
    ]
    expect(inTabOrder(sagas).map((saga) => saga.name)).toEqual([
      'untouched',
      'done',
      'newer',
      'older',
    ])
  })

  test('keeps the incoming order of sagas shelved on the same day', () => {
    const sagas = [
      { name: 'first', shelvedAt: at(5) },
      { name: 'second', shelvedAt: at(5) },
    ]
    expect(inTabOrder(sagas).map((saga) => saga.name)).toEqual(['first', 'second'])
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

describe('provisionalCatalogueOf', () => {
  const owned = (title: string, number: number) => ({
    title: BookTitle(title),
    authors: [AuthorName('Patrick Rothfuss')],
    series: {
      id: SeriesId('kingkiller--rothfuss'),
      name: SeriesName('Kingkiller'),
      volume: VolumeNumber(number),
      kind: 'main' as const,
    },
  })
  const saga = {
    id: SeriesId('kingkiller--rothfuss'),
    name: SeriesName('Kingkiller'),
    author: AuthorName('Patrick Rothfuss'),
  }

  // What the reader declared, drawn as a spine: their own volumes at their
  // numbers, and the saga's name standing in for every volume they lack.
  test('lays out the declared number of volumes, the owned ones by their title', () => {
    const catalogue = provisionalCatalogueOf(saga, [owned('La Peur du sage', 2)], VolumeNumber(3))

    expect(catalogue).toMatchObject({
      id: saga.id,
      name: saga.name,
      author: saga.author,
      provisional: true,
      volumes: [
        { number: VolumeNumber(1), title: BookTitle('Kingkiller'), kind: 'main' },
        { number: VolumeNumber(2), title: BookTitle('La Peur du sage'), kind: 'main' },
        { number: VolumeNumber(3), title: BookTitle('Kingkiller'), kind: 'main' },
      ],
    })
    expect(catalogue.description).toBeUndefined()
    expect(catalogue.volumes.every((volume) => volume.publishedIn === undefined)).toBe(true)
  })

  // A count below a volume on the shelf would make that volume vanish from
  // its own saga: the spine runs at least as far as what the reader holds.
  test('runs the spine up to the highest owned volume when the count falls short', () => {
    const catalogue = provisionalCatalogueOf(saga, [owned('Book Five', 5)], VolumeNumber(3))

    expect(catalogue.volumes.map((volume) => Number(volume.number))).toEqual([1, 2, 3, 4, 5])
    expect(catalogue.volumes[4]?.title).toBe(BookTitle('Book Five'))
  })

  test('leaves an unnumbered owned volume off the spine', () => {
    const novella = {
      ...owned('The Slow Regard', 1),
      series: {
        ...owned('The Slow Regard', 1).series,
        volume: undefined,
        kind: 'novella' as const,
      },
    }

    const catalogue = provisionalCatalogueOf(saga, [novella], VolumeNumber(2))

    expect(catalogue.volumes.map((volume) => String(volume.title))).toEqual([
      'Kingkiller',
      'Kingkiller',
    ])
  })
})

describe('cataloguesOf', () => {
  const kingkiller = SeriesId('kingkiller--rothfuss')
  const dune = SeriesId('dune--herbert')
  const volume = (seriesId: Series['id'], name: string, title: string, number: number) => ({
    title: BookTitle(title),
    authors: [AuthorName('Someone')],
    series: {
      id: seriesId,
      name: SeriesName(name),
      volume: VolumeNumber(number),
      kind: 'main' as const,
    },
  })
  const known: Series = {
    id: dune,
    name: SeriesName('Dune'),
    author: AuthorName('Frank Herbert'),
    volumes: [],
    catalogedAt: new Date('2026-01-01'),
  }

  // The world's catalogue when there is one, the reader's own count when
  // there is not, and nothing for a saga nobody described or counted.
  test('answers the stored catalogue first, then the declared count, then nothing', () => {
    const catalogues = cataloguesOf(
      [
        volume(dune, 'Dune', 'Dune', 1),
        volume(kingkiller, 'Kingkiller', 'The Name of the Wind', 1),
        volume(SeriesId('other'), 'Other', 'Other', 1),
      ],
      [known],
      [
        { seriesId: dune, volumeCount: VolumeNumber(9) },
        { seriesId: kingkiller, volumeCount: VolumeNumber(3) },
      ],
    )

    expect(catalogues.get(dune)).toBe(known)
    expect(catalogues.get(kingkiller)).toMatchObject({ provisional: true, author: 'Someone' })
    expect(catalogues.get(kingkiller)?.volumes).toHaveLength(3)
    expect(catalogues.has(SeriesId('other'))).toBe(false)
  })

  test('draws one provisional catalogue for a saga held in two languages', () => {
    const catalogues = cataloguesOf(
      [
        { ...volume(kingkiller, 'Kingkiller', 'Le Nom du vent', 1), language: 'fr' as const },
        { ...volume(kingkiller, 'Kingkiller', 'The Name of the Wind', 1), language: 'en' as const },
      ],
      [],
      [{ seriesId: kingkiller, volumeCount: VolumeNumber(2) }],
    )

    expect([...catalogues.keys()]).toEqual([kingkiller])
    // One spine over both editions, the first-shelved title standing for a
    // number both hold.
    expect(catalogues.get(kingkiller)?.volumes.map((volume) => String(volume.title))).toEqual([
      'Le Nom du vent',
      'Kingkiller',
    ])
  })
})
