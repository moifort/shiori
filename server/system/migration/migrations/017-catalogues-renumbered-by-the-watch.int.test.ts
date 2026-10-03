import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { cataloguesRenumberedByTheWatch } = await import(
  '~/system/migration/migrations/017-catalogues-renumbered-by-the-watch'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const run = () => cataloguesRenumberedByTheWatch.migrate({ db: fakeDb() })

const catalogue = (key: string, volumes: Record<string, unknown>[]) =>
  fake.seed('series', key, {
    id: key.split('~')[0],
    name: 'Saga',
    author: 'A',
    language: 'fr',
    volumes,
  })

describe('catalogues renumbered by the watch', () => {
  test('Foundation loses the volumes and the titles the reading order wrote in', async () => {
    // The watch numbered the saga with its two prequels first.
    catalogue('cycle-de-fondation--isaac-asimov~fr', [
      {
        number: 1,
        title: 'Fondation',
        kind: 'main',
        titles: { fr: 'Prélude à Fondation', en: 'Prelude to Foundation' },
        releases: { fr: '1988', en: '1988' },
        covers: { fr: 'https://covers/prelude.jpg' },
      },
      {
        number: 3,
        title: 'Seconde Fondation',
        kind: 'main',
        titles: { fr: 'Fondation' },
        releases: { fr: '1951' },
      },
      { number: 4, title: 'Fondation foudroyée', kind: 'main', releases: { fr: '1965' } },
      {
        number: 6,
        title: 'Fondation Foudroyée',
        kind: 'main',
        publishedIn: 1983,
        releases: { fr: '1983' },
        covers: { fr: 'https://covers/denoel.jpg' },
      },
      { title: 'Prélude à Fondation', kind: 'prequel' },
    ])

    expect(await run()).toEqual({ ok: true, transformed: 1 })
    expect(fake.data('series', 'cycle-de-fondation--isaac-asimov~fr')?.volumes).toEqual([
      {
        number: 1,
        title: 'Fondation',
        kind: 'main',
        titles: { en: 'Prelude to Foundation' },
        releases: { en: '1988' },
      },
      { number: 3, title: 'Seconde Fondation', kind: 'main' },
      { number: 4, title: 'Fondation foudroyée', kind: 'main', releases: { fr: '1965' } },
      { title: 'Prélude à Fondation', kind: 'prequel' },
    ])
  })

  test('volumes that all carry the saga’s name and a translated title are left alone', async () => {
    const volumes = [
      { number: 1, title: 'Saga', kind: 'main', releases: { fr: '2020' } },
      { number: 2, title: 'Saga', kind: 'main', releases: { fr: '2021' } },
      { number: 3, title: 'Saga', kind: 'main', releases: { fr: '2022' } },
      {
        number: 4,
        title: 'Four',
        kind: 'main',
        titles: { fr: 'Quatre' },
        releases: { fr: '2023' },
      },
    ]
    catalogue('saga--a~fr', volumes)

    expect(await run()).toEqual({ ok: true, transformed: 0 })
    expect(fake.data('series', 'saga--a~fr')?.volumes).toEqual(volumes)
  })
})
