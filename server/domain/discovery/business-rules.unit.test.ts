import { describe, expect, test } from 'bun:test'
import type { AudibleAsin } from '~/domain/audible/types'
import type { Book, BookLanguage, CoverUrl, Isbn13 } from '~/domain/book/types'
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
  test('is every volume out they do not hold, and the soonest one announced', () => {
    const watch = watchOf(carl, [
      volume(1, '2024-05-02'),
      volume(2, '2024-10-01'),
      volume(3),
      volume(5, '2027'),
      volume(4, '2027-02-12'),
    ])
    const releases = releasesOf(held(1), watch, undefined, today)
    expect(releases.available.map((entry) => entry.number)).toEqual([2, 3] as VolumeNumber[])
    expect(releases.next?.number).toBe(4 as VolumeNumber)
    expect(releases.next?.date).toBe('2027-02-12' as ReleaseDate)
  })

  test('is nothing before the saga was ever looked up', () => {
    expect(releasesOf(held(1), undefined, undefined, today)).toEqual({
      watched: false,
      available: [],
    })
  })

  test('counts a volume announced for this month as still to come', () => {
    const releases = releasesOf([], watchOf(carl, [volume(4, '2026-09')]), undefined, today)
    expect(releases.available).toEqual([])
    expect(releases.next?.number).toBe(4 as VolumeNumber)
  })

  test('sends a printed volume to Amazon by its ISBN, else by its title', () => {
    const watch = watchOf(carl, [
      volume(2, '2024-10-01', { isbn13: '9782226488176' as Isbn13 }),
      volume(3, '2025-01-01'),
    ])
    const [second, third] = releasesOf([], watch, undefined, today).available
    expect(second.store).toBe('amazon')
    expect(second.storeUrl).toBe('https://www.amazon.fr/s?k=9782226488176')
    expect(third.storeUrl).toBe('https://www.amazon.fr/s?k=Carl%203%20Matt%20Dinniman')
  })

  test('sends a recording to its Audible page once confirmed, else to a search', () => {
    const watch = watchOf(carlHeard, [
      volume(1, '2024-11-22', { asin: 'B0DM67WR2V' as AudibleAsin }),
      volume(2, '2025-03-01'),
    ])
    const [first, second] = releasesOf([], watch, undefined, today).available
    expect(first.store).toBe('audible')
    expect(first.storeUrl).toBe('https://www.audible.fr/pd/B0DM67WR2V')
    expect(second.storeUrl).toBe(
      'https://www.audible.fr/search?keywords=Carl%202%20Matt%20Dinniman',
    )
  })

  test('offers the volumes the catalogue shows missing, as the Series tab does', () => {
    // The catalogue knows volume 3, which the web search missed; volume 6 is
    // due next year by its first publication.
    const catalogue = {
      id: carl,
      name: 'Dungeon Crawler Carl',
      author: 'Matt Dinniman',
      catalogedAt: new Date('2026-01-01'),
      volumes: [
        { number: 1, title: 'Carl 1', kind: 'main', publishedIn: 2020 },
        { number: 2, title: 'Carl 2', kind: 'main', publishedIn: 2021 },
        {
          number: 3,
          title: 'Carl 3',
          kind: 'main',
          publishedIn: 2022,
          titles: { fr: 'Carl trois' },
          covers: { fr: 'https://covers/carl3-fr.jpg' },
        },
        { number: 6, title: 'Carl 6', kind: 'main', publishedIn: 2027 },
        { title: 'A Carl novella', kind: 'novella', publishedIn: 2023 },
      ],
    } as unknown as Series
    const watch = watchOf(carl, [
      volume(2, '2024-10-01', { coverUrl: 'https://covers/carl2.jpg' as CoverUrl }),
      volume(4, '2025-01-01'),
    ])
    const releases = releasesOf(held(1), watch, catalogue, today)
    expect(
      releases.available.map((entry): unknown[] => [entry.number, entry.title, entry.coverUrl]),
    ).toEqual([
      [2, 'Carl 2', 'https://covers/carl2.jpg'],
      [3, 'Carl trois', 'https://covers/carl3-fr.jpg'],
      [4, 'Carl 4', undefined],
    ])
    expect(releases.available[1].storeUrl).toBe(
      'https://www.amazon.fr/s?k=Carl%20trois%20Matt%20Dinniman',
    )
    expect(releases.next?.number).toBe(6 as VolumeNumber)
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
    expect(releases.available).toEqual([])
    expect(releases.next?.number).toBe(2 as VolumeNumber)
  })

  test('sends English readers to the American stores', () => {
    const [book] = releasesOf(
      [],
      watchOf(carl, [volume(2, '2024-01-01')], 'en'),
      undefined,
      today,
    ).available
    const [heard] = releasesOf(
      [],
      watchOf(carlHeard, [volume(2, '2024-01-01')], 'en'),
      undefined,
      today,
    ).available
    expect(book.storeUrl.startsWith('https://www.amazon.com/')).toBe(true)
    expect(heard.storeUrl.startsWith('https://www.audible.com/')).toBe(true)
  })
})

describe('the tab', () => {
  const row = (name: string, shelvedAt: string, available: number, next?: string): SagaDiscovery =>
    ({
      series: saga({ name: name as SeriesName, shelvedAt: new Date(shelvedAt) }),
      available: Array.from({ length: available }, (_, index) => volume(index + 1)),
      next: next ? volume(9, next) : undefined,
    }) as SagaDiscovery

  test('puts sagas with volumes to get first, then the soonest announcements, and drops the rest', () => {
    const ordered = inDiscoveryOrder([
      row('later', '2026-01-01', 0, '2027-06'),
      row('older', '2025-01-01', 1),
      row('sooner', '2026-01-01', 0, '2026-10-26'),
      row('nothing', '2026-01-01', 0),
      row('newer', '2026-05-01', 2, '2027-01-01'),
    ])
    expect(ordered.map((entry) => entry.series.name)).toEqual([
      'newer',
      'older',
      'sooner',
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
