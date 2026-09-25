import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { AuthorUseCase } = await import('~/domain/author/use-case')
const { BookCommand } = await import('~/domain/book/command')
const { SeriesOpinionCommand } = await import('~/domain/series-opinion/command')
const { SeriesId, SeriesName, VolumeNumber } = await import('~/domain/series/primitives')
const { AuthorName, BookTitle } = await import('~/domain/shared/primitives')

const reader = 'reader-1' as UserId

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

/** One author per saga, each saga catalogued with three volumes. */
const writeSagas = async (count: number) => {
  for (let index = 0; index < count; index++) {
    const id = SeriesId(`saga-${index}`)
    fake.seed('series', id, {
      id,
      name: `Saga ${index}`,
      author: `Author ${index}`,
      volumes: [1, 2, 3].map((number) => ({ number, title: `Tome ${number}`, kind: 'main' })),
    })
    await BookCommand.add(reader, {
      title: BookTitle(`Saga ${index}, tome 1`),
      authors: [AuthorName(`Author ${index}`)],
      status: 'read',
      series: { id, name: SeriesName(`Saga ${index}`), volume: VolumeNumber(1), kind: 'main' },
    })
  }
}

describe('a page of the Authors tab', () => {
  // The library and the opinions are one scan each; the catalogues are the
  // heavy documents, and a page reads those of its own authors only.
  test('reads the catalogues of its own authors’ sagas only', async () => {
    await writeSagas(12)
    const docReads = fake.docReads
    const queryReads = fake.queryReads

    const { items, hasMore } = await AuthorUseCase.followedPage(reader, { limit: 5, offset: 0 }, {})

    expect(items).toHaveLength(5)
    expect(hasMore).toBe(true)
    expect(fake.docReads - docReads).toBe(5)
    expect(fake.queryReads - queryReads).toBe(2)
  })

  test('puts the author the reader loves first, with their saga measured', async () => {
    await writeSagas(3)
    await SeriesOpinionCommand.setFavorite(reader, SeriesId('saga-2'), true)

    const { items } = await AuthorUseCase.followedPage(reader, { limit: 10, offset: 0 }, {})

    expect(items[0]?.name).toBe(AuthorName('Author 2'))
    expect(Number(items[0]?.favoriteCount)).toBe(1)
    expect(items[0]?.saga?.series.id).toBe(SeriesId('saga-2'))
    expect(items[0]?.saga).toMatchObject({ readCount: 1, totalCount: 3 })
  })

  test('keeps only the authors with a heart in the favourites', async () => {
    await writeSagas(3)
    await SeriesOpinionCommand.setFavorite(reader, SeriesId('saga-1'), true)

    const { items, hasMore } = await AuthorUseCase.followedPage(
      reader,
      { limit: 10, offset: 0 },
      { favorite: true },
    )

    expect(items.map((author) => String(author.name))).toEqual(['Author 1'])
    expect(hasMore).toBe(false)
  })

  test('answers the same rows as a whole list, cut to the page', async () => {
    await writeSagas(4)

    const whole = await AuthorUseCase.followedPage(reader, { limit: 10, offset: 0 }, {})
    const second = await AuthorUseCase.followedPage(reader, { limit: 2, offset: 2 }, {})

    expect(second.items.map((author) => author.key)).toEqual(
      whole.items.slice(2, 4).map((author) => author.key),
    )
    expect(second.hasMore).toBe(false)
  })

  test('reads no catalogue for an author who wrote no saga', async () => {
    await BookCommand.add(reader, {
      title: BookTitle('Standalone'),
      authors: [AuthorName('Solo')],
    })
    const docReads = fake.docReads

    const { items } = await AuthorUseCase.followedPage(reader, { limit: 10, offset: 0 }, {})

    expect(items.map((author) => [String(author.name), author.saga])).toEqual([['Solo', null]])
    expect(fake.docReads - docReads).toBe(0)
  })
})
