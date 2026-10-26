import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { SeriesUseCase } = await import('~/domain/series/use-case')
const { SeriesCommand } = await import('~/domain/series/command')
const { SeriesQuery } = await import('~/domain/series/query')
const { BookCommand } = await import('~/domain/book/command')
const { BookQuery } = await import('~/domain/book/query')
const { CatalogueCorrectionQuery } = await import('~/domain/catalogue-correction/query')
const { SagaKey, SeriesDescription, SeriesName, VolumeNumber } = await import(
  '~/domain/series/primitives'
)
const { AuthorName, BookTitle } = await import('~/domain/shared/primitives')

const reader = 'reader-1' as UserId
const other = 'reader-2' as UserId
const saga = SagaKey('naruto--masashi-kishimoto')

beforeEach(() => {
  resetFakeFirestore()
})

const catalogued = () =>
  SeriesCommand.catalogue({
    id: `${saga}~fr` as never,
    saga,
    language: 'fr',
    name: SeriesName('Naruto (French Edition)'),
    author: AuthorName('Masashi Kishimoto'),
    description: SeriesDescription('Une saga de pirates.'),
    volumes: [{ number: VolumeNumber(1), title: BookTitle('Naruto 1'), kind: 'main' }],
    catalogedAt: new Date('2026-10-01'),
  })

const shelve = (userId: UserId, volume: number) =>
  BookCommand.add(userId, {
    title: BookTitle(`Naruto ${volume}`),
    authors: [AuthorName('Masashi Kishimoto')],
    language: 'fr',
    series: {
      saga,
      name: SeriesName('Naruto (French Edition)'),
      volume: VolumeNumber(volume),
      kind: 'main',
    },
  })

describe('correcting a catalogued edition', () => {
  test('writes the name and description into the catalogue, and the name into every reader’s volumes', async () => {
    await catalogued()
    await shelve(reader, 1)
    await shelve(other, 2)

    const series = await SeriesUseCase.correct(reader, saga, 'fr', 'fr', {
      name: SeriesName('Naruto'),
      description: SeriesDescription('Un ninja orphelin rêve de devenir Hokage.'),
    })

    expect(series).toMatchObject({
      name: 'Naruto',
      description: 'Un ninja orphelin rêve de devenir Hokage.',
    })
    const stored = await SeriesQuery.byId({ saga, language: 'fr' })
    expect(stored?.corrected).toEqual(['name', 'description'])
    expect((await BookQuery.bySeries(other, saga))[0].series?.name).toBe(SeriesName('Naruto'))
    expect(await CatalogueCorrectionQuery.byUser(reader)).toMatchObject([
      {
        catalogue: 'series',
        documentId: `${saga}~fr`,
        field: 'name',
        before: 'Naruto (French Edition)',
        after: 'Naruto',
      },
      { field: 'description', before: 'Une saga de pirates.' },
    ])
  })

  test('keeps what was corrected when the catalogue is asked again', async () => {
    await catalogued()
    await shelve(reader, 1)
    await SeriesUseCase.correct(reader, saga, 'fr', 'fr', {
      name: SeriesName('Naruto'),
      description: undefined,
    })

    const again = await catalogued()

    expect(again.name).toBe(SeriesName('Naruto'))
    expect(again.description).toBeUndefined()
    expect(again.corrected).toEqual(['name', 'description'])
  })

  test('turns every volume the reader holds into the format, and no one else’s', async () => {
    await catalogued()
    await shelve(reader, 1)
    await shelve(reader, 2)
    await shelve(other, 1)

    await SeriesUseCase.correct(reader, saga, 'fr', 'fr', { format: 'manga' })

    expect((await BookQuery.bySeries(reader, saga)).map((book) => book.format)).toEqual([
      'manga',
      'manga',
    ])
    expect((await BookQuery.bySeries(other, saga))[0].format).toBe('book')
    expect(await CatalogueCorrectionQuery.byUser(reader)).toEqual([])
  })

  test('refuses a recording either way', async () => {
    await catalogued()
    await shelve(reader, 1)

    expect(await SeriesUseCase.correct(reader, saga, 'fr', 'fr', { format: 'audiobook' })).toBe(
      'audio-format',
    )
  })

  test('is not found for an edition the reader holds nothing of', async () => {
    await catalogued()
    await shelve(other, 1)

    expect(await SeriesUseCase.correct(reader, saga, 'fr', 'fr', { format: 'manga' })).toBe(
      'not-found',
    )
  })
})

describe('correcting an edition nobody catalogued', () => {
  test('renames the reader’s volumes alone', async () => {
    await shelve(reader, 1)
    await shelve(other, 1)

    await SeriesUseCase.correct(reader, saga, 'fr', 'fr', { name: SeriesName('Naruto') })

    expect((await BookQuery.bySeries(reader, saga))[0].series?.name).toBe(SeriesName('Naruto'))
    expect((await BookQuery.bySeries(other, saga))[0].series?.name).toBe(
      SeriesName('Naruto (French Edition)'),
    )
    expect(await SeriesQuery.byId({ saga, language: 'fr' })).toBeNull()
  })

  test('takes no description, which would mark it catalogued', async () => {
    await shelve(reader, 1)

    expect(
      await SeriesUseCase.correct(reader, saga, 'fr', 'fr', {
        description: SeriesDescription('Un ninja.'),
      }),
    ).toBe('not-catalogued')
    expect(await SeriesQuery.byId({ saga, language: 'fr' })).toBeNull()
  })
})
