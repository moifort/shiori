import { describe, expect, test } from 'bun:test'
import type { AudibleAsin } from '~/domain/audible/types'
import type { Book, BookLanguage } from '~/domain/book/types'
import type { ReleaseDate, Series, SeriesId, SeriesName, VolumeNumber } from '~/domain/series/types'
import type { FollowedSeries } from '~/domain/series/use-case'
import type { BookTitle, UserId } from '~/domain/shared/types'
import {
  alertOf,
  dueAlertsOf,
  dueWatches,
  inDiscoveryOrder,
  likelyLanguageOf,
  mergedVolumes,
  missingVolumesOf,
  onAudible,
  releasesOf,
  watchedSagasOf,
} from './business-rules'
import type { DiscoveryReader, FoundVolume, SagaDiscovery, SagaWatch } from './types'

const carl = 'dungeon-crawler-carl--matt-dinniman' as SeriesId
const carlHeard = 'dungeon-crawler-carl--matt-dinniman--audio' as SeriesId

const volume = (number: number, date?: string, extra: Partial<FoundVolume> = {}): FoundVolume => ({
  number: number as VolumeNumber,
  title: `Carl ${number}` as BookTitle,
  ...(date ? { date: date as ReleaseDate } : {}),
  ...extra,
})

const watchOf = (
  seriesId: SeriesId,
  volumes: FoundVolume[],
  language: BookLanguage = 'fr',
): SagaWatch => ({
  key: `${seriesId}--${language}`,
  seriesId,
  name: 'Dungeon Crawler Carl' as SeriesName,
  author: 'Matt Dinniman' as never,
  language,
  checkedAt: new Date('2026-09-01'),
  volumes,
})

const held = (...numbers: number[]) =>
  numbers.map(
    (number) =>
      ({ series: { id: carl, volume: number, kind: 'main' } }) as unknown as Pick<Book, 'series'>,
  )

const saga = (overrides: Partial<FollowedSeries>): FollowedSeries =>
  ({
    id: carl,
    name: 'Dungeon Crawler Carl',
    author: 'Matt Dinniman',
    language: 'fr',
    state: 'in-progress',
    books: [],
    shelvedAt: new Date('2026-01-01'),
    ...overrides,
  }) as FollowedSeries

const today = '2026-09-26'

describe('the sagas watched for a reader', () => {
  test('are every saga they follow in the language they hold it in, but the ones set aside', () => {
    const sagas = watchedSagasOf([
      saga({}),
      saga({ id: 'set-aside' as SeriesId, state: 'unfollowed' }),
      saga({ id: 'no-language' as SeriesId, language: undefined }),
      saga({ id: 'not-started' as SeriesId, state: 'not-started' }),
    ])
    expect(sagas.map((entry) => entry.seriesId)).toEqual([carl, 'not-started' as SeriesId])
    expect(sagas[0]).toEqual({
      seriesId: carl,
      language: 'fr',
      name: 'Dungeon Crawler Carl' as SeriesName,
      author: 'Matt Dinniman' as never,
    })
  })

  test('are looked up the ones never looked up first, then the longest unchecked', () => {
    const reader = (sagas: DiscoveryReader['sagas']): DiscoveryReader => ({
      userId: 'bob' as UserId,
      language: 'fr',
      sagas,
      syncedAt: new Date(),
      notified: [],
    })
    const fresh = {
      seriesId: 'fresh' as SeriesId,
      language: 'fr' as const,
      name: 'F' as SeriesName,
    }
    const old = { seriesId: 'old' as SeriesId, language: 'fr' as const, name: 'O' as SeriesName }
    const never = {
      seriesId: 'never' as SeriesId,
      language: 'fr' as const,
      name: 'N' as SeriesName,
    }
    const now = new Date('2026-09-26')
    const watches = new Map([
      ['fresh--fr', { ...watchOf('fresh' as SeriesId, []), checkedAt: new Date('2026-09-25') }],
      ['old--fr', { ...watchOf('old' as SeriesId, []), checkedAt: new Date('2026-08-01') }],
    ])
    expect(
      dueWatches([reader([fresh, old]), reader([never, old])], watches, now).map(
        (entry) => entry.seriesId,
      ),
    ).toEqual(['never' as SeriesId, 'old' as SeriesId])
  })

  test('write to the reader in the app language they read most sagas in', () => {
    const in_ = (language: 'fr' | 'en' | 'de') => ({
      seriesId: 'x' as SeriesId,
      language,
      name: 'X' as SeriesName,
    })
    expect(likelyLanguageOf([in_('fr'), in_('fr'), in_('en')])).toBe('fr')
    expect(likelyLanguageOf([in_('de')])).toBe('en')
    expect(likelyLanguageOf([])).toBe('en')
  })
})

describe('what a saga has for the reader', () => {
  test('is the soonest volume announced, never one already out', () => {
    const watch = watchOf(carl, [
      volume(1, '2024-05-02'),
      volume(2, '2024-10-01'),
      volume(3),
      volume(5, '2027'),
      volume(4, '2027-02-12'),
    ])
    const releases = releasesOf(held(1), watch, undefined, today)
    expect(releases).toEqual({ watched: true, next: volume(4, '2027-02-12') })
  })

  test('is nothing before the saga was ever looked up', () => {
    expect(releasesOf(held(1), undefined, undefined, today)).toEqual({ watched: false })
  })

  test('is nothing but watched when nothing is announced', () => {
    expect(releasesOf([], watchOf(carl, [volume(2, '2024-10-01')]), undefined, today)).toEqual({
      watched: true,
    })
  })

  test('counts a volume announced for this month as still to come', () => {
    const releases = releasesOf([], watchOf(carl, [volume(4, '2026-09')]), undefined, today)
    expect(releases.next?.number).toBe(4 as VolumeNumber)
  })

  test('skips an announced volume the reader already holds', () => {
    const watch = watchOf(carl, [volume(4, '2027-02-12'), volume(5, '2027-09-01')])
    expect(releasesOf(held(4), watch, undefined, today).next?.number).toBe(5 as VolumeNumber)
  })

  test('reads what is announced off the catalogue the Series tab draws', () => {
    // Volume 6 is due next year by its first publication, and only the
    // catalogue knows it.
    const catalogue = {
      id: carl,
      name: 'Dungeon Crawler Carl',
      author: 'Matt Dinniman',
      catalogedAt: new Date('2026-01-01'),
      volumes: [
        { number: 1, title: 'Carl 1', kind: 'main', publishedIn: 2020 },
        { number: 2, title: 'Carl 2', kind: 'main', publishedIn: 2021 },
        { number: 6, title: 'Carl 6', kind: 'main', publishedIn: 2027 },
        { title: 'A Carl novella', kind: 'novella', publishedIn: 2027 },
      ],
    } as unknown as Series
    const watch = watchOf(carl, [volume(2, '2024-10-01'), volume(4, '2025-01-01')])
    expect(releasesOf(held(1), watch, catalogue, today).next?.number).toBe(6 as VolumeNumber)
  })

  // A saga opened for the first time after its watch: the catalogue only
  // knows the year, the watch knows the day.
  test('reads the day the watch found over a catalogue written after it', () => {
    const catalogue = {
      id: carl,
      name: 'Dungeon Crawler Carl',
      author: 'Matt Dinniman',
      catalogedAt: new Date('2026-09-27'),
      volumes: [
        { number: 4, title: 'Carl 4', kind: 'main', publishedIn: 2026 },
        { number: 5, title: 'Carl 5', kind: 'main', publishedIn: 2026 },
      ],
    } as unknown as Series
    const watch = watchOf(carl, [volume(4, '2026-05-01'), volume(5, '2026-10-08')])
    expect(releasesOf(held(4), watch, catalogue, today).next).toEqual(volume(5, '2026-10-08'))
    expect(missingVolumesOf(held(4), watch, catalogue, today)).toEqual([])
  })

  test('holds a volume back while the catalogue says it is not out in that edition', () => {
    const catalogue = {
      id: carl,
      name: 'Dungeon Crawler Carl',
      author: 'Matt Dinniman',
      catalogedAt: new Date('2026-01-01'),
      volumes: [{ number: 2, title: 'Carl 2', kind: 'main', releases: { fr: '2027-03-01' } }],
    } as unknown as Series
    const releases = releasesOf([], watchOf(carl, [volume(2)]), catalogue, today)
    expect(releases.next?.number).toBe(2 as VolumeNumber)
  })
})

describe('the volumes a saga has out for the reader', () => {
  test('are the numbers of the volumes out they do not hold, in order', () => {
    const watch = watchOf(carl, [
      volume(3, '2025-01-01'),
      volume(1, '2024-05-02'),
      volume(2, '2024-10-01'),
      volume(4, '2027-02-12'),
    ])
    expect(missingVolumesOf(held(2), watch, undefined, today)).toEqual([1, 3] as VolumeNumber[])
  })

  test('leave out a volume out in English but not yet in French', () => {
    // System Universe: book 5 came out in English in 2024, the French
    // translation only follows, and the French watch has not dated it yet.
    const catalogue = {
      id: carl,
      name: 'Dungeon Crawler Carl',
      author: 'Matt Dinniman',
      catalogedAt: new Date('2026-01-01'),
      volumes: [
        ...[1, 2, 3, 4].map((number) => ({
          number,
          title: `Carl ${number}`,
          kind: 'main',
          publishedIn: 2022,
          releases: { en: '2022-01-01', fr: `2025-0${number}-01` },
        })),
        {
          number: 5,
          title: 'Carl 5',
          kind: 'main',
          publishedIn: 2024,
          releases: { en: '2024-03-01' },
        },
      ],
    } as unknown as Series
    const watch = watchOf(
      carl,
      [1, 2, 3, 4].map((number) => volume(number, `2025-0${number}-01`)),
    )
    expect(missingVolumesOf(held(1, 2), watch, catalogue, today)).toEqual([3, 4] as VolumeNumber[])
  })

  test('are none before the saga was ever looked up', () => {
    expect(missingVolumesOf([], undefined, undefined, today)).toEqual([])
  })
})

describe('a saga heard', () => {
  test('is what Audible lists, and beyond it only what is announced', () => {
    const listed = [volume(1, '2025-01-16'), volume(5, '2026-10-08')]
    const found = [volume(5, '2024-03-01'), volume(6, '2027'), volume(7, '2025-01-01')]
    expect(onAudible(listed, found, today)).toEqual([
      volume(1, '2025-01-16'),
      volume(5, '2026-10-08'),
      volume(6, '2027'),
    ])
  })
})

describe('the tab', () => {
  const row = (name: string, next?: string): SagaDiscovery =>
    ({
      series: saga({ name: name as SeriesName }),
      watched: true,
      next: next ? volume(9, next) : undefined,
      missing: [],
    }) as SagaDiscovery

  test('lists the dated announcements, the soonest first, and drops the rest', () => {
    const ordered = inDiscoveryOrder([
      row('later', '2027-06'),
      row('sooner', '2026-10-26'),
      row('nothing'),
      row('middle', '2027-01-01'),
    ])
    expect(ordered.map((entry) => entry.series.name)).toEqual([
      'sooner',
      'middle',
      'later',
    ] as SeriesName[])
  })
})

describe('a fresh look', () => {
  test('keeps a volume the search missed, and what it knew of the ones found again', () => {
    const merged = mergedVolumes(
      [
        volume(1, '2024-01-01', { asin: 'B0DM67WR2V' as AudibleAsin, coverUrl: 'c1' as never }),
        volume(2, '2025-01-01'),
      ],
      [volume(1, '2024-01-02'), volume(3, '2027')],
    )
    expect(merged).toEqual([
      volume(1, '2024-01-02', { asin: 'B0DM67WR2V' as AudibleAsin, coverUrl: 'c1' as never }),
      volume(2, '2025-01-01'),
      volume(3, '2027'),
    ])
  })
})

describe('alerts', () => {
  const reader: DiscoveryReader = {
    userId: 'bob' as UserId,
    language: 'fr',
    sagas: [{ seriesId: carl, language: 'fr', name: 'Dungeon Crawler Carl' as SeriesName }],
    syncedAt: new Date(),
    notified: [`${carl}--fr--2`],
  }
  const watches = new Map([
    [
      `${carl}--fr`,
      watchOf(carl, [
        volume(1, '2026-01-01'),
        volume(2, '2026-09-20'),
        volume(3, '2026-09-26'),
        volume(4, '2026-09'),
        volume(5, '2026-09-27'),
      ]),
    ],
  ])

  test('go out for a volume out to the day in the last two weeks, once', () => {
    expect(dueAlertsOf(reader, watches, today).map((alert) => alert.key)).toEqual([
      `${carl}--fr--3`,
    ])
  })

  test('name the volume and its saga in the reader’s language', () => {
    const [due] = dueAlertsOf(reader, watches, today)
    expect(alertOf(due, 'fr')).toEqual({
      title: 'Nouveau tome',
      body: '« Carl 3 », tome 3 de Dungeon Crawler Carl, est sorti.',
    })
    expect(alertOf({ ...due, watch: watchOf(carlHeard, []) }, 'en').body).toBe(
      '"Carl 3", book 3 of Dungeon Crawler Carl, is out as an audiobook.',
    )
  })
})
