import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { cataloguesWithoutALanguageAreFrench } = await import(
  '~/system/migration/migrations/016-catalogues-without-a-language-are-french'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const run = () => cataloguesWithoutALanguageAreFrench.migrate({ db: fakeDb() })

const heldInFrench = (seriesId: string) =>
  fake.seed('books', `book-${seriesId}`, {
    userId: 'r',
    title: 'Tome 1',
    language: 'fr',
    series: { id: seriesId, name: 'Saga', volume: 1, kind: 'main' },
  })

const catalogue = (key: string, fields: Record<string, unknown> = {}) =>
  fake.seed('series', key, {
    id: key.split('~')[0],
    name: 'Saga',
    author: 'A',
    volumes: [{ number: 1, title: 'Tome 1', kind: 'main' }],
    ...fields,
  })

describe('catalogues without a language are French', () => {
  test('a saga held in French with no French catalogue keeps the bare one as it', async () => {
    heldInFrench('kindred')
    catalogue('kindred', {
      volumes: [
        {
          number: 1,
          title: 'Spark of the Everflame',
          kind: 'main',
          titles: { fr: 'Étincelle' },
          releases: { fr: '2025-03-05', en: '2023-01-01' },
        },
      ],
    })

    await run()
    expect(fake.data('series', 'kindred')).toBeNull()
    expect(fake.data('series', 'kindred~fr')).toMatchObject({
      id: 'kindred',
      language: 'fr',
      volumes: [{ number: 1, title: 'Étincelle', kind: 'main', releases: { fr: '2025-03-05' } }],
    })
  })

  test('a French catalogue already there is left as it was, the bare one goes', async () => {
    heldInFrench('poirot')
    catalogue('poirot', { name: 'Old' })
    catalogue('poirot~fr', { language: 'fr', name: 'Hercule Poirot' })

    await run()
    expect(fake.data('series', 'poirot')).toBeNull()
    expect(fake.data('series', 'poirot~fr')?.name).toBe('Hercule Poirot')
  })

  test('a bare catalogue nobody holds in French goes without a copy', async () => {
    catalogue('orphan')
    catalogue('dune~en', { language: 'en' })

    await run()
    expect(fake.data('series', 'orphan')).toBeNull()
    expect(fake.data('series', 'orphan~fr')).toBeNull()
    expect(fake.data('series', 'dune~en')).not.toBeNull()
  })

  test('a bare record of an empty answer goes, an edition’s stays', async () => {
    fake.seed('series-misses', 'heard--a--audio', { id: 'heard--a--audio' })
    fake.seed('series-misses', 'heard--a--audio~fr', { id: 'heard--a--audio', language: 'fr' })

    await run()
    expect(fake.data('series-misses', 'heard--a--audio')).toBeNull()
    expect(fake.data('series-misses', 'heard--a--audio~fr')).not.toBeNull()
  })
})
