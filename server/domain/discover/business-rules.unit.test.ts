import { describe, expect, test } from 'bun:test'
import type { AudibleAsin, AudibleRelease } from '~/domain/audible/types'
import type { Book, BookId, CoverUrl } from '~/domain/book/types'
import {
  alertOf,
  audibleTranslationsOf,
  datedEditionsOf,
  dueEditions,
  editionsOf,
  foreignWorksOf,
  isUpcoming,
  ownedInLanguage,
  translationsOf,
} from '~/domain/discover/business-rules'
import { editionFrom } from '~/domain/discover/parsing'
import { ReleaseDate } from '~/domain/discover/primitives'
import type {
  DatedEdition,
  ForeignWork,
  TranslatedEdition,
  TranslationWatch,
} from '~/domain/discover/types'
import type { SeriesId, SeriesName, VolumeNumber } from '~/domain/series/types'
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
  status: 'read',
  hidden: false,
  addedAt: at('2026-01-01'),
  ...fields,
})
const saga = (name: string, volume: number) => ({
  id: `${name.toLowerCase().replace(/ /g, '-')}--x` as SeriesId,
  name: name as SeriesName,
  volume: volume as VolumeNumber,
  kind: 'main' as const,
})
const title = (value: string) => value as BookTitle
const volume = (value: number) => value as VolumeNumber

const carl: ForeignWork = {
  key: 'series--dungeon-crawler-carl--x',
  kind: 'series',
  title: title('Dungeon Crawler Carl'),
  author: 'Matt Dinniman' as AuthorName,
  language: 'en',
  volumesRead: [volume(1), volume(2)],
  cover: {},
  lastActivity: at('2026-09-01').getTime(),
}
const hailMary: ForeignWork = {
  key: 'book--project-hail-mary--andy-weir',
  kind: 'book',
  title: title('Project Hail Mary'),
  author: 'Andy Weir' as AuthorName,
  language: 'en',
  volumesRead: [],
  cover: { publishedCoverUrl: 'https://covers/phm.jpg' as CoverUrl },
  lastActivity: at('2026-08-01').getTime(),
}

const edition = (fields: Partial<TranslatedEdition>): TranslatedEdition => ({
  title: title('Untitled'),
  format: 'book',
  ...fields,
})

const recording = (fields: Partial<AudibleRelease>): AudibleRelease =>
  ({
    asin: 'B000000001' as AudibleAsin,
    title: title('Untitled'),
    authors: ['Matt Dinniman' as AuthorName],
    narrators: [],
    subgenres: [],
    status: 'to-read',
    alreadyInLibrary: false,
    language: 'fr',
    ...fields,
  }) as AudibleRelease

const watchOf = (work: ForeignWork, fields: Partial<TranslationWatch>): TranslationWatch => ({
  key: `${work.key}--fr`,
  kind: work.kind,
  title: work.title,
  author: work.author,
  language: 'fr',
  checkedAt: at('2026-09-20'),
  editions: [],
  ...fields,
})

describe('what the reader read in another language', () => {
  const library = [
    book({
      title: title('Dungeon Crawler Carl'),
      authors: ['Matt Dinniman' as AuthorName],
      language: 'en',
      series: saga('Dungeon Crawler Carl', 2),
      finishedAt: at('2026-09-01'),
    }),
    book({
      title: title('Carl’s Doomsday Scenario'),
      authors: ['Matt Dinniman' as AuthorName],
      language: 'en',
      status: 'reading',
      series: saga('Dungeon Crawler Carl', 1),
      finishedAt: at('2026-08-01'),
    }),
    book({
      title: title('Project Hail Mary'),
      authors: ['Andy Weir' as AuthorName],
      language: 'en',
      finishedAt: at('2026-07-01'),
    }),
    book({ title: title('Dune'), language: 'fr' }),
    book({ title: title('Piranesi'), language: 'en', status: 'to-read' }),
    book({ title: title('Sans langue') }),
  ]

  test('is one work per saga and per book on its own, the most recent first', () => {
    const works = foreignWorksOf(library, 'fr')

    expect(works.map((work): unknown[] => [work.key, work.kind, work.title as string])).toEqual([
      ['series--dungeon-crawler-carl--x', 'series', 'Dungeon Crawler Carl'],
      ['book--project-hail-mary--andy-weir', 'book', 'Project Hail Mary'],
    ])
    expect(works[0].volumesRead).toEqual([volume(1), volume(2)])
  })

  test('leaves out the pile, the app’s language and a book of no known language', () => {
    expect(foreignWorksOf(library, 'en')).toEqual([
      expect.objectContaining({ title: 'Dune', language: 'fr' }),
    ])
  })

  test('owns a translation only through a book in the app’s language', () => {
    const owned = ownedInLanguage(
      [
        book({
          title: title('Red Rising'),
          authors: ['Pierce Brown' as AuthorName],
          language: 'en',
        }),
        book({ title: title('Dune'), authors: ['Frank Herbert' as AuthorName], language: 'fr' }),
      ],
      'fr',
    )

    expect([...owned]).toEqual(['dune--frank-herbert'])
  })
})

describe('the recordings Audible lists for a work', () => {
  test('are a saga’s volumes, under its own name or its translated one', () => {
    const found = audibleTranslationsOf(carl, title('Carl, le donjon'), [
      recording({
        asin: 'B000000001' as AudibleAsin,
        title: title('Carl, le donjon'),
        series: {
          id: 'x' as SeriesId,
          name: 'Carl, le donjon' as SeriesName,
          volume: volume(1),
          kind: 'main',
        },
        releaseDate: at('2025-03-01'),
      }),
      recording({
        asin: 'B000000002' as AudibleAsin,
        title: title('Le Livre de recettes'),
        series: {
          id: 'x' as SeriesId,
          name: 'Dungeon Crawler Carl' as SeriesName,
          volume: volume(2),
          kind: 'main',
        },
      }),
      recording({ asin: 'B000000003' as AudibleAsin, title: title('Autre chose') }),
      recording({
        asin: 'B000000004' as AudibleAsin,
        authors: ['Somebody Else' as AuthorName],
        series: {
          id: 'x' as SeriesId,
          name: 'Dungeon Crawler Carl' as SeriesName,
          volume: volume(3),
          kind: 'main',
        },
      }),
    ])

    expect(found.map((found): unknown[] => [found.volume, found.audibleAsin, found.date])).toEqual([
      [1, 'B000000001', '2025-03-01'],
      [2, 'B000000002', undefined],
    ])
  })

  test('are a book on its own, under its translated title', () => {
    const found = audibleTranslationsOf(hailMary, title('Projet Dernière Chance'), [
      recording({ title: title('Projet dernière chance'), authors: ['Andy Weir' as AuthorName] }),
      recording({ title: title('Seul sur Mars'), authors: ['Andy Weir' as AuthorName] }),
    ])

    expect(found.map((found) => found.title as string)).toEqual(['Projet dernière chance'])
  })
})

describe('the editions a reader is offered', () => {
  const watch = watchOf(carl, {
    editions: [
      edition({ title: title('Carl 1'), volume: volume(1), format: 'book' }),
      edition({
        title: title('Carl 1'),
        volume: volume(1),
        format: 'audiobook',
        date: ReleaseDate('2025-01'),
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
    expect(editionsOf(carl, watch, undefined, new Set()).map((e) => e.format)).toEqual(['book'])
  })

  test('take Audible’s recording over the web’s for the same volume', () => {
    const audible = [
      edition({
        title: title('Carl 1'),
        volume: volume(1),
        format: 'audiobook',
        audibleAsin: 'B1' as AudibleAsin,
      }),
    ]

    const editions = editionsOf(carl, watch, audible, new Set())

    expect(editions.map((e): unknown[] => [e.volume, e.format, e.audibleAsin])).toEqual([
      [1, 'audiobook', 'B1'],
      [1, 'book', undefined],
      [4, 'audiobook', undefined],
    ])
  })

  test('never hold one the reader already owns', () => {
    const owned = new Set(['carl-1--matt-dinniman'])

    expect(editionsOf(carl, watch, [], owned).map((e) => e.volume)).toEqual([volume(4)])
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
      `${carl.key}--fr`,
      watchOf(carl, {
        translatedTitle: title('Carl, le donjon'),
        editions: [
          edition({ title: title('Carl 1'), volume: volume(1) }),
          edition({ title: title('Carl 4'), volume: volume(4), date: ReleaseDate('2027-02-19') }),
        ],
      }),
    ],
    [
      `${hailMary.key}--fr`,
      watchOf(hailMary, {
        editions: [
          edition({ title: title('Projet Dernière Chance'), date: ReleaseDate('2021-10-06') }),
        ],
      }),
    ],
  ])
  const feed = { language: 'fr' as const, dismissed: [] as string[] }

  test('puts a work with an edition to come in upcoming, the rest in available', () => {
    const { upcoming, available } = translationsOf(
      [carl, hailMary],
      watches,
      feed,
      new Set(),
      '2026-09-24',
    )

    expect(upcoming.map((t): unknown[] => [t.title as string, t.nextDate])).toEqual([
      ['Carl, le donjon', '2027-02-19'],
    ])
    expect(
      available.map((t): unknown[] => [t.title as string, t.originalTitle as string, t.coverUrl]),
    ).toEqual([['Projet Dernière Chance', 'Project Hail Mary', 'https://covers/phm.jpg']])
  })

  test('leaves out a work the reader is not interested in, and one with nothing translated', () => {
    const { upcoming, available } = translationsOf(
      [carl, hailMary, { ...hailMary, key: 'book--untranslated--x' }],
      watches,
      { ...feed, dismissed: [carl.key] },
      new Set(),
      '2026-09-24',
    )

    expect([...upcoming, ...available].map((t) => t.key)).toEqual([hailMary.key])
  })
})

describe('the alerts', () => {
  const dated: DatedEdition = {
    key: `${carl.key}--audiobook--4`,
    workKey: carl.key,
    title: title('Carl 4'),
    volume: volume(4),
    format: 'audiobook',
    date: ReleaseDate('2027-02-19'),
  }

  test('keep the editions dated to the day, recent or to come', () => {
    const kept = datedEditionsOf(
      [
        {
          key: carl.key,
          kind: 'series',
          title: title('Carl'),
          originalTitle: title('Carl'),
          originalLanguage: 'en',
          volumesRead: [],
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
        },
      ],
      '2026-09-24',
    )

    expect(kept).toEqual([dated])
  })

  test('go out on the day, and up to two weeks late, once', () => {
    const feed = { dated: [dated], notified: [], dismissed: [] }

    expect(dueEditions(feed, '2027-02-18')).toEqual([])
    expect(dueEditions(feed, '2027-02-19')).toEqual([dated])
    expect(dueEditions(feed, '2027-03-04')).toEqual([dated])
    expect(dueEditions(feed, '2027-03-06')).toEqual([])
    expect(dueEditions({ ...feed, notified: [dated.key] }, '2027-02-19')).toEqual([])
    expect(dueEditions({ ...feed, dismissed: [carl.key] }, '2027-02-19')).toEqual([])
  })

  test('say what came out, in the reader’s language', () => {
    expect(alertOf(dated, 'fr')).toEqual({
      title: 'Enfin traduit',
      body: '« Carl 4 », tome 4, est disponible en français en livre audio.',
    })
    expect(alertOf({ ...dated, volume: undefined, format: 'book' }, 'en').body).toBe(
      '"Carl 4" is out in English.',
    )
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
