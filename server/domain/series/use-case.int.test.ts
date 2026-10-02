import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { SeriesUseCase } = await import('~/domain/series/use-case')
const { BookCommand } = await import('~/domain/book/command')
const { SeriesId, SeriesName, VolumeNumber } = await import('~/domain/series/primitives')
const { BookTitle } = await import('~/domain/shared/primitives')
const { BookQuery } = await import('~/domain/book/query')
const { SeriesOpinionCommand } = await import('~/domain/series-opinion/command')
const { SeriesOpinionQuery } = await import('~/domain/series-opinion/query')

const reader = 'reader-1' as UserId
const NOW = new Date('2026-09-22T10:00:00.000Z')

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

/** Sagas shelved newest first: saga-0 is the most recent. Each is catalogued
 *  in French, the edition a book that names no language is taken to be in. */
const followSagas = async (count: number) => {
  for (let index = 0; index < count; index++) {
    const id = SeriesId(`saga-${index}`)
    fake.seed('series', `${id}~fr`, {
      id,
      language: 'fr',
      name: `Saga ${index}`,
      author: 'A',
      volumes: [],
    })
    await BookCommand.add(
      reader,
      {
        title: BookTitle(`Saga ${index}, tome 1`),
        series: { id, name: SeriesName(`Saga ${index}`), volume: VolumeNumber(1), kind: 'main' },
      },
      new Date(NOW.getTime() - index * 60_000),
    )
  }
}

describe('a page of the Series tab', () => {
  // The catalogues are the heavy documents of the tab: a page reads its own,
  // not those of every saga the reader follows.
  test('reads the catalogues of its own sagas only', async () => {
    await followSagas(12)
    const before = fake.docReads

    const { items, hasMore } = await SeriesUseCase.followedPage(reader, { limit: 5, offset: 0 }, {})

    expect(items.map((saga) => String(saga.id))).toEqual([
      'saga-0',
      'saga-1',
      'saga-2',
      'saga-3',
      'saga-4',
    ])
    expect(items.every((saga) => saga.catalogue !== null)).toBe(true)
    expect(hasMore).toBe(true)
    expect(fake.docReads - before).toBe(5)
  })

  test('answers the same rows as the whole list, cut to the page', async () => {
    await followSagas(4)

    const { items } = await SeriesUseCase.followedPage(reader, { limit: 2, offset: 2 }, {})
    const all = await SeriesUseCase.followed(reader)

    expect(items).toEqual(all.filter((saga) => ['saga-2', 'saga-3'].includes(String(saga.id))))
  })

  test('reads every catalogue when it filters on a state', async () => {
    await followSagas(6)
    const before = fake.docReads

    const { items } = await SeriesUseCase.followedPage(
      reader,
      { limit: 2, offset: 0 },
      { state: 'not-started' },
    )

    expect(items).toHaveLength(2)
    expect(fake.docReads - before).toBe(6)
  })
})

describe('the name of a row', () => {
  // The catalogue names the saga as the world does, and the saga screen shows
  // that name: the row must not keep the one a scan or an import wrote.
  test("is the catalogue's once there is one", async () => {
    const id = SeriesId('saga-0')
    fake.seed('series', `${id}~fr`, {
      id,
      language: 'fr',
      name: 'The Saga',
      author: 'A',
      volumes: [],
    })
    await BookCommand.add(
      reader,
      {
        title: BookTitle('Saga, tome 1'),
        series: { id, name: SeriesName('saga'), volume: VolumeNumber(1), kind: 'main' },
      },
      NOW,
    )

    const [row] = await SeriesUseCase.followed(reader)

    expect(String(row?.name)).toBe('The Saga')
  })

  test("is the books' while nobody has catalogued the saga", async () => {
    await BookCommand.add(
      reader,
      {
        title: BookTitle('Saga, tome 1'),
        series: {
          id: SeriesId('saga-0'),
          name: SeriesName('saga'),
          volume: VolumeNumber(1),
          kind: 'main',
        },
      },
      NOW,
    )

    const [row] = await SeriesUseCase.followed(reader)

    expect(String(row?.name)).toBe('saga')
  })
})

describe('one row of the Series tab', () => {
  // What the tab asks after the reader edited a saga: the row it shows, and
  // only its catalogue — not a page of every saga to find it in.
  test('answers the same row as the whole list, reading its catalogue only', async () => {
    await followSagas(6)
    const before = fake.docReads

    const row = await SeriesUseCase.followedOne(reader, SeriesId('saga-3'), 'fr')
    expect(fake.docReads - before).toBe(1)

    const all = await SeriesUseCase.followed(reader)
    expect(row).toEqual(all.find((saga) => String(saga.id) === 'saga-3') ?? null)
  })

  test('answers nothing for a saga the reader no longer holds', async () => {
    await followSagas(1)

    expect(await SeriesUseCase.followedOne(reader, SeriesId('saga-9'))).toBeNull()
  })

  // A saga held in two languages is two rows: the one asked for, not the other.
  test('answers the edition asked for', async () => {
    await followSagas(1)
    const id = SeriesId('saga-0')

    expect(await SeriesUseCase.followedOne(reader, id, 'en')).toBeNull()
    expect((await SeriesUseCase.followedOne(reader, id, 'fr'))?.language).toBe('fr')
  })
})

describe('the name a saga goes by', () => {
  const redRising = SeriesId('red-rising-french-edition--pierre-brown--audio')
  const volumeOf = (name: string, reader: UserId, volume: number) =>
    BookCommand.add(
      reader,
      {
        title: BookTitle(`Red Rising ${volume}`),
        format: 'audiobook',
        series: {
          id: redRising,
          name: SeriesName(name),
          volume: VolumeNumber(volume),
          kind: 'main',
        },
      },
      NOW,
    )

  test('is the catalogue’s on a book about to be added', async () => {
    fake.seed('series', redRising, { id: redRising, name: 'Red Rising', author: 'A', volumes: [] })
    const book = {
      title: BookTitle('Red Rising 2'),
      format: 'audiobook' as const,
      series: {
        id: redRising,
        name: SeriesName('Red Rising[French Edition]'),
        volume: VolumeNumber(2),
        kind: 'main' as const,
      },
    }
    const standalone: { title: ReturnType<typeof BookTitle>; series?: undefined } = {
      title: BookTitle('Seul'),
    }

    const [named, alone] = await SeriesUseCase.namedAfterCatalogues([book, standalone])

    expect(named.series?.name).toBe(SeriesName('Red Rising'))
    expect(alone).toEqual(standalone)
  })

  test('is written into every reader’s volumes once the saga is catalogued', async () => {
    const first = await volumeOf('Red Rising[French Edition]', reader, 1)
    const other = await volumeOf('Red Rising [French Edition]', 'reader-2' as UserId, 2)

    expect(
      await BookCommand.nameSeries({ id: redRising, language: 'fr' }, SeriesName('Red Rising')),
    ).toBe(2)

    for (const book of [first, other])
      expect(fake.data('books', book.id)?.series).toMatchObject({ name: 'Red Rising' })
    expect(fake.data('books', first.id)?.updatedAt).toEqual(first.updatedAt)
  })
})

describe('a saga held in two languages', () => {
  const dune = SeriesId('dune--frank-herbert')
  const volumeIn = (language: 'fr' | 'en', name: string) =>
    BookCommand.add(
      reader,
      {
        title: BookTitle(`${name} 1`),
        language,
        series: { id: dune, name: SeriesName(name), volume: VolumeNumber(1), kind: 'main' },
      },
      NOW,
    )

  beforeEach(() => {
    fake.seed('series', `${dune}~fr`, {
      id: dune,
      language: 'fr',
      name: 'Le Cycle de Dune',
      author: 'Frank Herbert',
      volumes: [
        { number: 1, title: 'Dune', kind: 'main' },
        { number: 2, title: 'Le Messie de Dune', kind: 'main' },
      ],
    })
    fake.seed('series', `${dune}~en`, {
      id: dune,
      language: 'en',
      name: 'Dune Chronicles',
      author: 'Frank Herbert',
      volumes: [
        { number: 1, title: 'Dune', kind: 'main' },
        { number: 2, title: 'Dune Messiah', kind: 'main' },
        { number: 3, title: 'Children of Dune', kind: 'main' },
      ],
    })
  })

  test('draws each row from its own edition’s catalogue', async () => {
    await volumeIn('fr', 'Dune')
    await volumeIn('en', 'Dune')

    const rows = await SeriesUseCase.followed(reader)

    expect(rows.map((row) => [row.language, String(row.name), row.progress?.totalCount])).toEqual([
      ['en', 'Dune Chronicles', 3],
      ['fr', 'Le Cycle de Dune', 2],
    ])
  })

  test('names a book about to be added after its own edition', async () => {
    const book = (language: 'fr' | 'en') => ({
      title: BookTitle('Dune 2'),
      language,
      series: {
        id: dune,
        name: SeriesName('Dune'),
        volume: VolumeNumber(2),
        kind: 'main' as const,
      },
    })

    const [french, english] = await SeriesUseCase.namedAfterCatalogues([book('fr'), book('en')])

    expect(String(french?.series?.name)).toBe('Le Cycle de Dune')
    expect(String(english?.series?.name)).toBe('Dune Chronicles')
  })

  test('renames only the volumes of the edition catalogued', async () => {
    const french = await volumeIn('fr', 'Dune')
    const english = await volumeIn('en', 'Dune')

    expect(
      await BookCommand.nameSeries({ id: dune, language: 'fr' }, SeriesName('Le Cycle de Dune')),
    ).toBe(1)

    expect(fake.data('books', french.id)?.series).toMatchObject({ name: 'Le Cycle de Dune' })
    expect(fake.data('books', english.id)?.series).toMatchObject({ name: 'Dune' })
  })

  test('opens the saga screen on the edition asked for, else on a volume held', async () => {
    await volumeIn('en', 'Dune')

    expect(
      (await SeriesUseCase.describe(reader, dune, 'fr', 'fr'))?.volumes.map((volume) =>
        String(volume.title),
      ),
    ).toEqual(['Dune', 'Le Messie de Dune'])
    expect((await SeriesUseCase.describe(reader, dune, 'fr'))?.language).toBe('en')
  })
})

describe('merging a duplicate saga', () => {
  const kept = SeriesId('assassin-royal--robin-hobb')
  const duplicate = SeriesId('l-assassin-royal-french-edition--robin-hobb')

  const shelve = (id: typeof kept, name: string, volume: number, language: 'fr' | 'en' = 'fr') =>
    BookCommand.add(
      reader,
      {
        title: BookTitle(`${name}, tome ${volume}`),
        language,
        series: { id, name: SeriesName(name), volume: VolumeNumber(volume), kind: 'main' },
      },
      NOW,
    )

  test('files every volume under the kept saga, at its number and under its name', async () => {
    await shelve(kept, "L'Assassin royal", 1)
    await shelve(duplicate, "L'Assassin royal (French Edition)", 2)
    await shelve(duplicate, "L'Assassin royal (French Edition)", 3)

    expect(await SeriesUseCase.mergeInto(reader, duplicate, undefined, kept)).toBe(2)

    expect(await BookQuery.bySeries(reader, duplicate)).toEqual([])
    const volumes = await BookQuery.bySeries(reader, kept)
    expect(volumes.map((book) => `${book.series?.name} ${book.series?.volume}`).sort()).toEqual([
      "L'Assassin royal 1",
      "L'Assassin royal 2",
      "L'Assassin royal 3",
    ])
  })

  test("forgets the duplicate's opinion and keeps the kept saga's", async () => {
    await shelve(kept, "L'Assassin royal", 1)
    await shelve(duplicate, 'Assassin', 2)
    await SeriesOpinionCommand.setFavorite(reader, kept, true)
    await SeriesOpinionCommand.setFavorite(reader, duplicate, true)

    await SeriesUseCase.mergeInto(reader, duplicate, undefined, kept)

    expect(await SeriesOpinionQuery.of(reader, duplicate)).toBeNull()
    expect((await SeriesOpinionQuery.of(reader, kept))?.favorite).toBe(true)
  })

  test('moves only the edition named, and the duplicate keeps its opinion while it remains', async () => {
    await shelve(kept, "L'Assassin royal", 1)
    await shelve(duplicate, 'Assassin', 2, 'fr')
    await shelve(duplicate, "Assassin's Apprentice", 1, 'en')
    await SeriesOpinionCommand.setFavorite(reader, duplicate, true)

    expect(await SeriesUseCase.mergeInto(reader, duplicate, 'fr', kept)).toBe(1)

    const left = await BookQuery.bySeries(reader, duplicate)
    expect(left.map((book) => book.language)).toEqual(['en'])
    expect((await SeriesOpinionQuery.of(reader, duplicate))?.favorite).toBe(true)
  })

  test('refuses a saga the reader does not hold, itself, and another format', async () => {
    await shelve(duplicate, 'Assassin', 2)

    expect(await SeriesUseCase.mergeInto(reader, duplicate, undefined, kept)).toBe('not-found')
    expect(await SeriesUseCase.mergeInto(reader, duplicate, undefined, duplicate)).toBe(
      'same-series',
    )
    expect(
      await SeriesUseCase.mergeInto(reader, duplicate, undefined, SeriesId(`${kept}--audio`)),
    ).toBe('other-format')
    expect(await BookQuery.bySeries(reader, duplicate)).toHaveLength(1)
  })
})
