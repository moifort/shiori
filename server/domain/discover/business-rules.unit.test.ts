import { describe, expect, test } from 'bun:test'
import type { Book, BookId, BookLanguage, CoverUrl } from '~/domain/book/types'
import {
  alertOf,
  datedEditionsOf,
  dueEditions,
  editionsOf,
  foundVolumesOf,
  isUpcoming,
  ownedEditionsOf,
  releasesOf,
  watchedWorksOf,
} from '~/domain/discover/business-rules'
import { editionFrom } from '~/domain/discover/parsing'
import { ReleaseDate } from '~/domain/discover/primitives'
import type {
  DatedEdition,
  Release,
  ReleaseEdition,
  ReleaseWatch,
  WatchedWork,
} from '~/domain/discover/types'
import type { SeriesId, SeriesName, SeriesState, VolumeNumber } from '~/domain/series/types'
import type { FollowedSeries } from '~/domain/series/use-case'
import type { AuthorName, BookTitle, Count, UserId } from '~/domain/shared/types'

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
  status: 'read',
  hidden: false,
  addedAt: at('2026-01-01'),
  ...fields,
})
const title = (value: string) => value as BookTitle
const volume = (value: number) => value as VolumeNumber
const carlId = 'dungeon-crawler-carl--matt-dinniman' as SeriesId

const carlVolume = (number: number, language: BookLanguage = 'en') =>
  book({
    title: title(`Carl ${number}`),
    authors: ['Matt Dinniman' as AuthorName],
    language,
    series: {
      id: carlId,
      name: 'Dungeon Crawler Carl' as SeriesName,
      volume: volume(number),
      kind: 'main',
    },
  })

const row = (
  language: BookLanguage,
  state: SeriesState | null,
  books: Book[] = [carlVolume(1, language), carlVolume(2, language)],
): FollowedSeries => ({
  id: carlId,
  name: 'Dungeon Crawler Carl' as SeriesName,
  author: 'Matt Dinniman' as AuthorName,
  language,
  catalogue: null,
  opinion: null,
  state,
  progress: null,
  ownedCount: books.length as Count,
  books,
  shelvedAt: at('2026-09-01'),
})

const work = (fields: Partial<WatchedWork>): WatchedWork => ({
  key: `series--${carlId}--fr`,
  kind: 'series',
  seriesId: carlId,
  title: title('Dungeon Crawler Carl'),
  author: 'Matt Dinniman' as AuthorName,
  language: 'fr',
  readIn: 'en',
  volumesRead: [volume(1), volume(2)],
  cover: {},
  lastActivity: at('2026-09-01').getTime(),
  ...fields,
})
const carlFr = work({})
const carlEn = work({ key: `series--${carlId}--en`, language: 'en' })
const hailMary = work({
  key: 'book--project-hail-mary--andy-weir--fr',
  kind: 'book',
  seriesId: undefined,
  title: title('Project Hail Mary'),
  author: 'Andy Weir' as AuthorName,
  volumesRead: [],
  cover: { publishedCoverUrl: 'https://covers/phm.jpg' as CoverUrl },
  lastActivity: at('2026-08-01').getTime(),
})

const edition = (fields: Partial<ReleaseEdition>): ReleaseEdition => ({
  title: title('Untitled'),
  format: 'book',
  ...fields,
})

const watchOf = (of: WatchedWork, fields: Partial<ReleaseWatch>): ReleaseWatch => ({
  key: of.key,
  kind: of.kind,
  title: of.title,
  author: of.author,
  language: of.language,
  checkedAt: at('2026-09-20'),
  editions: [],
  ...fields,
})

describe('what the reader follows', () => {
  test('a saga read in English is watched in English and in French', () => {
    const works = watchedWorksOf([row('en', 'complete')], [], 'fr')

    expect(works.map((entry): unknown[] => [entry.key, entry.language, entry.readIn])).toEqual([
      [`series--${carlId}--en`, 'en', 'en'],
      [`series--${carlId}--fr`, 'fr', 'en'],
    ])
    expect(works[0].volumesRead).toEqual([volume(1), volume(2)])
  })

  test('a saga read in the app’s language, or held in it too, is watched once per edition', () => {
    expect(watchedWorksOf([row('fr', 'in-progress')], [], 'fr').map((entry) => entry.key)).toEqual([
      `series--${carlId}--fr`,
    ])
    expect(
      watchedWorksOf([row('en', 'in-progress'), row('fr', 'in-progress')], [], 'fr').map(
        (entry) => entry.key,
      ),
    ).toEqual([`series--${carlId}--en`, `series--${carlId}--fr`])
  })

  test('leaves out a saga set aside or not started', () => {
    for (const state of ['unfollowed', 'not-started'] as const)
      expect(watchedWorksOf([row('en', state)], [], 'fr')).toEqual([])
  })

  test('watches a saga nobody catalogued, whose next volume is exactly what is unknown', () => {
    expect(watchedWorksOf([row('fr', null)], [], 'fr')).toHaveLength(1)
  })

  test('watches a book on its own read in another language for its translation', () => {
    const works = watchedWorksOf(
      [],
      [
        book({
          title: title('Project Hail Mary'),
          authors: ['Andy Weir' as AuthorName],
          language: 'en',
        }),
        book({ title: title('Dune'), language: 'fr' }),
        book({ title: title('Piranesi'), language: 'en', status: 'to-read' }),
        book({ title: title('Sans langue') }),
        carlVolume(1),
      ],
      'fr',
    )

    expect(works.map((entry): unknown[] => [entry.key, entry.kind, entry.readIn])).toEqual([
      ['book--project-hail-mary--andy-weir--fr', 'book', 'en'],
    ])
  })

  test('owns an edition only in its own language', () => {
    const owned = ownedEditionsOf([
      book({ title: title('Red Rising'), authors: ['Pierce Brown' as AuthorName], language: 'en' }),
      carlVolume(3, 'fr'),
    ])

    expect([...owned]).toEqual([
      'en|red-rising--pierce-brown',
      'fr|carl-3--matt-dinniman',
      `fr|${carlId}#3`,
    ])
  })
})

describe('the editions a reader is offered', () => {
  const watch = watchOf(carlFr, {
    editions: [
      edition({ title: title('Carl 1'), volume: volume(1), format: 'book' }),
      edition({
        title: title('Carl 1'),
        volume: volume(1),
        format: 'audiobook',
        date: ReleaseDate('2025-01'),
      }),
      edition({
        title: title('Le Donjon'),
        volume: volume(3),
        format: 'book',
      }),
      edition({
        title: title('Carl 4'),
        volume: volume(4),
        format: 'audiobook',
        date: ReleaseDate('2027-05'),
      }),
    ],
  })

  test('hold no recording for a reader not connected to Audible', () => {
    expect(editionsOf(carlFr, watch, false, new Set()).map((e) => e.format)).toEqual([
      'book',
      'book',
    ])
  })

  test('hold every format, one per volume, for a reader connected to it', () => {
    const editions = editionsOf(carlFr, watch, true, new Set())

    expect(editions.map((e): unknown[] => [e.volume, e.format])).toEqual([
      [1, 'book'],
      [1, 'audiobook'],
      [3, 'book'],
      [4, 'audiobook'],
    ])
  })

  test('never hold one the reader owns in that language, by title or by number', () => {
    const owned = ownedEditionsOf([
      book({ title: title('Carl 1'), authors: ['Matt Dinniman' as AuthorName], language: 'fr' }),
      carlVolume(3, 'fr'),
      carlVolume(4, 'en'),
    ])

    expect(editionsOf(carlFr, watch, true, owned).map((e) => e.volume)).toEqual([volume(4)])
  })
})

describe('whether an edition is still to come', () => {
  const today = '2026-09-24'

  test('by the day, or until its month or year is over', () => {
    expect(isUpcoming(edition({ date: ReleaseDate('2026-09-25') }), today)).toBe(true)
    expect(isUpcoming(edition({ date: ReleaseDate('2026-09-24') }), today)).toBe(false)
    expect(isUpcoming(edition({ date: ReleaseDate('2026-09') }), today)).toBe(true)
    expect(isUpcoming(edition({ date: ReleaseDate('2026-08') }), today)).toBe(false)
    expect(isUpcoming(edition({ date: ReleaseDate('2026') }), today)).toBe(true)
    expect(isUpcoming(edition({}), today)).toBe(false)
  })
})

describe('the tab', () => {
  const watches = new Map([
    [
      carlFr.key,
      watchOf(carlFr, {
        localTitle: title('Carl, le donjon'),
        editions: [
          edition({ title: title('Carl 1'), volume: volume(1) }),
          edition({ title: title('Carl 4'), volume: volume(4), date: ReleaseDate('2026-10-08') }),
        ],
      }),
    ],
    [
      carlEn.key,
      watchOf(carlEn, {
        editions: [
          edition({ title: title('Carl 3'), volume: volume(3), date: ReleaseDate('2024-01-01') }),
          edition({
            title: title('Carl 8'),
            volume: volume(8),
            date: ReleaseDate('2026-12'),
            coverUrl: 'https://covers/carl8.jpg' as CoverUrl,
          }),
        ],
      }),
    ],
    [
      hailMary.key,
      watchOf(hailMary, {
        editions: [
          edition({ title: title('Projet Dernière Chance'), date: ReleaseDate('2021-10-06') }),
        ],
      }),
    ],
  ])
  const feed = { dismissed: [] as string[] }

  test('puts every edition with a volume to come in upcoming, whatever its language', () => {
    const { upcoming, maybe } = releasesOf(
      [carlEn, carlFr, hailMary],
      watches,
      feed,
      undefined,
      new Set(),
      '2026-09-24',
    )

    expect(
      upcoming.map((release): unknown[] => [
        release.title as string,
        release.language,
        release.nextDate,
        release.coverUrl,
      ]),
    ).toEqual([
      ['Carl, le donjon', 'fr', '2026-10-08', undefined],
      ['Dungeon Crawler Carl', 'en', '2026-12', 'https://covers/carl8.jpg'],
    ])
    expect(maybe.map((release): unknown[] => [release.title as string, release.coverUrl])).toEqual([
      ['Projet Dernière Chance', 'https://covers/phm.jpg'],
    ])
  })

  test('proposes a translation out, never a volume out in the language already read', () => {
    const noNext = new Map(watches)
    noNext.set(
      carlEn.key,
      watchOf(carlEn, {
        editions: [
          edition({ title: title('Carl 3'), volume: volume(3), date: ReleaseDate('2024-01-01') }),
        ],
      }),
    )
    const { upcoming, maybe } = releasesOf(
      [carlEn],
      noNext,
      feed,
      undefined,
      new Set(),
      '2026-09-24',
    )

    expect([...upcoming, ...maybe]).toEqual([])
  })

  test('leaves out a work the reader is not interested in, and one with nothing found', () => {
    const { upcoming, maybe } = releasesOf(
      [carlFr, hailMary, { ...hailMary, key: 'book--untranslated--x--fr' }],
      watches,
      { dismissed: [carlFr.key] },
      undefined,
      new Set(),
      '2026-09-24',
    )

    expect([...upcoming, ...maybe].map((release) => release.key)).toEqual([hailMary.key])
  })
})

describe('what a saga’s watch writes into its catalogue', () => {
  test('the numbered printed volumes, with their date and cover', () => {
    const watch = watchOf(carlFr, {
      editions: [
        edition({
          title: title('Carl 4'),
          volume: volume(4),
          date: ReleaseDate('2026-10-08'),
          coverUrl: 'https://covers/4.jpg' as CoverUrl,
        }),
        edition({ title: title('Carl 4'), volume: volume(4), format: 'audiobook' }),
        edition({ title: title('Hors-série') }),
      ],
    })

    expect(foundVolumesOf(watch)).toEqual([
      {
        volume: volume(4),
        title: title('Carl 4'),
        date: ReleaseDate('2026-10-08'),
        coverUrl: 'https://covers/4.jpg' as CoverUrl,
      },
    ])
  })
})

describe('the alerts', () => {
  const dated: DatedEdition = {
    key: `${carlFr.key}--audiobook--4`,
    workKey: carlFr.key,
    title: title('Carl 4'),
    volume: volume(4),
    format: 'audiobook',
    date: ReleaseDate('2027-02-19'),
    language: 'fr',
    translation: true,
  }

  const release = (fields: Partial<Release>): Release => ({
    key: carlFr.key,
    kind: 'series',
    language: 'fr',
    readIn: 'en',
    title: title('Carl'),
    editions: [],
    ...fields,
  })

  test('keep the editions dated to the day, recent or to come', () => {
    const kept = datedEditionsOf(
      [
        release({
          editions: [
            edition({
              title: title('Carl 4'),
              volume: volume(4),
              format: 'audiobook',
              date: ReleaseDate('2027-02-19'),
            }),
            edition({ title: title('Carl 5'), volume: volume(5), date: ReleaseDate('2027-06') }),
            edition({ title: title('Carl 1'), volume: volume(1), date: ReleaseDate('2025-01-01') }),
          ],
        }),
      ],
      '2026-09-24',
    )

    expect(kept).toEqual([dated])
  })

  test('know a next volume from a translation', () => {
    const [next] = datedEditionsOf(
      [
        release({
          key: carlEn.key,
          language: 'en',
          editions: [
            edition({ title: title('Carl 8'), volume: volume(8), date: ReleaseDate('2026-12-01') }),
          ],
        }),
      ],
      '2026-09-24',
    )

    expect(next).toMatchObject({ language: 'en', translation: false })
  })

  test('go out on the day, and up to two weeks late, once', () => {
    const feed = { dated: [dated], notified: [], dismissed: [] }

    expect(dueEditions(feed, '2027-02-18')).toEqual([])
    expect(dueEditions(feed, '2027-02-19')).toEqual([dated])
    expect(dueEditions(feed, '2027-03-04')).toEqual([dated])
    expect(dueEditions(feed, '2027-03-06')).toEqual([])
    expect(dueEditions({ ...feed, notified: [dated.key] }, '2027-02-19')).toEqual([])
    expect(dueEditions({ ...feed, dismissed: [carlFr.key] }, '2027-02-19')).toEqual([])
  })

  test('say what came out, in the reader’s language', () => {
    expect(alertOf(dated, 'fr')).toEqual({
      title: 'Enfin traduit',
      body: '« Carl 4 », tome 4, est disponible en français en livre audio.',
    })
    expect(alertOf({ ...dated, volume: undefined, format: 'book' }, 'en').body).toBe(
      '"Carl 4" is out in English.',
    )
    expect(alertOf({ ...dated, format: 'book', translation: false }, 'fr')).toEqual({
      title: 'Nouveau tome',
      body: '« Carl 4 », tome 4, est sorti.',
    })
    expect(alertOf({ ...dated, format: 'book', translation: false }, 'en')).toEqual({
      title: 'New volume',
      body: '"Carl 4", book 4, is out.',
    })
  })
})

describe('reading an edition out of the model’s answer', () => {
  test('refuses an edition in another language than the one asked', () => {
    expect(editionFrom({ title: 'Project Hail Mary', format: 'book', language: 'en' }, 'fr')).toBe(
      undefined,
    )
  })

  test('keeps an edition whose date or ISBN does not hold, without them', () => {
    expect(
      editionFrom(
        { title: 'Carl 4', format: 'audiobook', volume: 4, date: '2027-02-30', isbn13: 'nope' },
        'fr',
      ),
    ).toEqual({
      title: title('Carl 4'),
      volume: volume(4),
      format: 'audiobook',
      date: undefined,
      isbn13: undefined,
    })
  })
})
