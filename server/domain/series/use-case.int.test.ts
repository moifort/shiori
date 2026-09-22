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
