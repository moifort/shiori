import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { SeriesCommand } = await import('~/domain/series/command')
const { SeriesQuery } = await import('~/domain/series/query')
const { ReleaseDate, SeriesId, SeriesName, VolumeNumber } = await import(
  '~/domain/series/primitives'
)
const { AuthorName, BookTitle, Year } = await import('~/domain/shared/primitives')
const { withRequestCacheScope } = await import('~/system/request-cache')

const id = SeriesId('system-universe--dakota-krout')

const catalogue = () => ({
  id,
  name: SeriesName('System Universe'),
  author: AuthorName('Dakota Krout'),
  catalogedAt: new Date('2026-01-01'),
  volumes: [
    {
      number: VolumeNumber(4),
      title: BookTitle('Four'),
      kind: 'main' as const,
      publishedIn: Year(2024),
    },
  ],
})

beforeEach(() => {
  resetFakeFirestore()
})

describe('release dates written into the catalogue', () => {
  test('an announced volume joins the saga with its date', async () => {
    await SeriesCommand.catalogue(catalogue())
    await withRequestCacheScope(() =>
      SeriesCommand.recordReleases(id, 'fr', [
        { volume: VolumeNumber(5), title: BookTitle('Cinq'), date: ReleaseDate('2026-10-08') },
      ]),
    )
    const stored = await withRequestCacheScope(() => SeriesQuery.byId(id))
    expect(stored?.volumes.map((volume) => volume.releases?.fr as string | undefined)).toEqual([
      undefined,
      '2026-10-08',
    ])
  })

  test('a saga nobody catalogued is left alone', async () => {
    expect(
      await SeriesCommand.recordReleases(SeriesId('nobody--nobody'), 'fr', [
        { volume: VolumeNumber(1), title: BookTitle('Un') },
      ]),
    ).toBeNull()
    expect(await SeriesQuery.byId(SeriesId('nobody--nobody'))).toBeNull()
  })

  test('building the catalogue again keeps the dates', async () => {
    await SeriesCommand.catalogue(catalogue())
    await withRequestCacheScope(() =>
      SeriesCommand.recordReleases(id, 'fr', [
        { volume: VolumeNumber(4), title: BookTitle('Quatre'), date: ReleaseDate('2025-02-01') },
      ]),
    )
    await withRequestCacheScope(() => SeriesCommand.catalogue(catalogue()))
    const stored = await withRequestCacheScope(() => SeriesQuery.byId(id))
    expect(stored?.volumes[0]).toMatchObject({
      releases: { fr: '2025-02-01' },
      titles: { fr: 'Quatre' },
    })
  })
})
