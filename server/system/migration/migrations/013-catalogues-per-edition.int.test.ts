import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { cataloguesPerEdition } = await import(
  '~/system/migration/migrations/013-catalogues-per-edition'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const catalogedAt = new Date('2026-09-20T10:00:00Z')

describe('catalogues per edition', () => {
  test('each language held or dated gets its own catalogue, with its titles, dates and covers', async () => {
    fake.seed('series', 'dune--herbert', {
      id: 'dune--herbert',
      name: 'Dune',
      author: 'Frank Herbert',
      catalogedAt,
      volumes: [
        {
          number: 1,
          title: 'Dune',
          kind: 'main',
          publishedIn: 1965,
          releases: { fr: '1970', en: '1965-08-01' },
          covers: { fr: 'https://covers/fr-1.jpg' },
        },
        {
          number: 2,
          title: 'Dune Messiah',
          kind: 'main',
          titles: { fr: 'Le Messie de Dune' },
          releases: { en: '1969' },
        },
      ],
    })
    fake.seed('books', 'b1', { userId: 'u1', series: { id: 'dune--herbert' }, language: 'fr' })
    fake.seed('books', 'b2', { userId: 'u2', series: { id: 'dune--herbert' } })

    const result = await cataloguesPerEdition.migrate({ db: fakeDb() })

    expect(result).toEqual({ ok: true, transformed: 2 })
    expect(fake.data('series', 'dune--herbert~fr')).toMatchObject({
      id: 'dune--herbert',
      language: 'fr',
      name: 'Dune',
      volumes: [
        {
          number: 1,
          title: 'Dune',
          releases: { fr: '1970' },
          covers: { fr: 'https://covers/fr-1.jpg' },
        },
        { number: 2, title: 'Le Messie de Dune' },
      ],
    })
    const french = fake.data('series', 'dune--herbert~fr') as { volumes: object[] }
    expect(french.volumes[1]).not.toHaveProperty('releases')
    expect(french.volumes[1]).not.toHaveProperty('titles')
    expect(fake.data('series', 'dune--herbert~en')).toMatchObject({
      language: 'en',
      volumes: [
        { number: 1, releases: { en: '1965-08-01' } },
        { number: 2, title: 'Dune Messiah', releases: { en: '1969' } },
      ],
    })
    // The shared catalogue stays, for the volumes that record no language.
    expect(fake.data('series', 'dune--herbert')).not.toBeNull()
  })

  test('an edition already split is left alone, and a second run writes nothing', async () => {
    fake.seed('series', 'carl--dinniman', {
      id: 'carl--dinniman',
      name: 'Dungeon Crawler Carl',
      author: 'Matt Dinniman',
      catalogedAt,
      volumes: [{ number: 1, title: 'Dungeon Crawler Carl', kind: 'main' }],
    })
    fake.seed('series', 'carl--dinniman~fr', {
      id: 'carl--dinniman',
      language: 'fr',
      name: 'Carl le donjonneur',
      author: 'Matt Dinniman',
      catalogedAt,
      volumes: [],
    })
    fake.seed('books', 'b1', { userId: 'u1', series: { id: 'carl--dinniman' }, language: 'fr' })
    fake.seed('books', 'b2', { userId: 'u1', series: { id: 'carl--dinniman' }, language: 'en' })

    expect(await cataloguesPerEdition.migrate({ db: fakeDb() })).toEqual({
      ok: true,
      transformed: 1,
    })
    expect(fake.data('series', 'carl--dinniman~fr')).toMatchObject({ name: 'Carl le donjonneur' })
    expect(await cataloguesPerEdition.migrate({ db: fakeDb() })).toEqual({
      ok: true,
      transformed: 0,
    })
  })
})
