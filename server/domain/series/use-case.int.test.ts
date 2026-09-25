import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { SeriesUseCase } = await import('~/domain/series/use-case')
const { BookCommand } = await import('~/domain/book/command')
const { SeriesId, SeriesName, VolumeNumber } = await import('~/domain/series/primitives')
const { BookTitle } = await import('~/domain/shared/primitives')

const reader = 'reader-1' as UserId
const NOW = new Date('2026-09-22T10:00:00.000Z')

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

/** Sagas shelved newest first: saga-0 is the most recent. Each is catalogued. */
const followSagas = async (count: number) => {
  for (let index = 0; index < count; index++) {
    const id = SeriesId(`saga-${index}`)
    fake.seed('series', id, { id, name: `Saga ${index}`, author: 'A', volumes: [] })
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
    fake.seed('series', id, { id, name: 'The Saga', author: 'A', volumes: [] })
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

    const row = await SeriesUseCase.followedOne(reader, SeriesId('saga-3'))
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

    expect(await SeriesUseCase.followedOne(reader, id, 'fr')).toBeNull()
    expect((await SeriesUseCase.followedOne(reader, id))?.language).toBeUndefined()
  })
})
