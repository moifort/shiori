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
  language: 'fr' as const,
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
    const stored = await withRequestCacheScope(() => SeriesQuery.byId({ id, language: 'fr' }))
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
    expect(await SeriesQuery.byId({ id: SeriesId('nobody--nobody'), language: 'fr' })).toBeNull()
  })

  test('building the catalogue again keeps the dates', async () => {
    await SeriesCommand.catalogue(catalogue())
    await withRequestCacheScope(() =>
      SeriesCommand.recordReleases(id, 'fr', [
        { volume: VolumeNumber(4), title: BookTitle('Quatre'), date: ReleaseDate('2025-02-01') },
      ]),
    )
    await withRequestCacheScope(() => SeriesCommand.catalogue(catalogue()))
    const stored = await withRequestCacheScope(() => SeriesQuery.byId({ id, language: 'fr' }))
    expect(stored?.volumes[0]).toMatchObject({
      releases: { fr: '2025-02-01' },
      titles: { fr: 'Quatre' },
    })
  })

  test("an edition's dates go into that edition's catalogue only", async () => {
    await SeriesCommand.catalogue(catalogue())
    await SeriesCommand.catalogue({ ...catalogue(), language: 'en' })
    await withRequestCacheScope(() =>
      SeriesCommand.recordReleases(id, 'en', [
        { volume: VolumeNumber(4), title: BookTitle('Four'), date: ReleaseDate('2024-03-01') },
      ]),
    )
    const [french, english] = await withRequestCacheScope(() =>
      Promise.all([
        SeriesQuery.byId({ id, language: 'fr' }),
        SeriesQuery.byId({ id, language: 'en' }),
      ]),
    )
    expect(french?.volumes[0]?.releases).toBeUndefined()
    expect(english?.volumes[0]?.releases).toEqual({ en: ReleaseDate('2024-03-01') })
  })

  test('a watch on an edition nobody catalogued leaves the other editions alone', async () => {
    await SeriesCommand.catalogue(catalogue())
    expect(
      await withRequestCacheScope(() =>
        SeriesCommand.recordReleases(id, 'en', [
          { volume: VolumeNumber(5), title: BookTitle('Five'), date: ReleaseDate('2026-10-08') },
        ]),
      ),
    ).toBeNull()
    const french = await withRequestCacheScope(() => SeriesQuery.byId({ id, language: 'fr' }))
    expect(french?.volumes).toHaveLength(1)
  })
})
