import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { releasesHoldTheirDescriptions } = await import(
  '~/system/migration/migrations/036-releases-hold-their-descriptions'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const describedAt = new Date('2026-11-01T08:00:00Z')
const checkedAt = new Date('2026-11-02T08:00:00Z')
const description = (title: string) => ({ book: { title, coverUrl: 'https://c/x.jpg' } })

describe('releases hold their descriptions', () => {
  test('moves an unannounced edition watch and the description of its original', async () => {
    fake.seed('edition-watches', 'ragazza-nella-nebbia--donato-carrisi--audiobook--fr', {
      key: 'ragazza-nella-nebbia--donato-carrisi--audiobook--fr',
      title: 'La ragazza nella nebbia',
      author: 'Donato Carrisi',
      originalLanguage: 'it',
      format: 'audiobook',
      language: 'fr',
      checkedAt,
    })
    fake.seed('release-descriptions', 'ragazza-nella-nebbia~donato-carrisi~audiobook~it~-~fr', {
      description: description('La ragazza nella nebbia'),
      describedAt,
    })

    const result = await releasesHoldTheirDescriptions.migrate({ db: fakeDb() })

    expect(result).toEqual({ ok: true, transformed: 1 })
    const release = fake
      .snapshot('releases')
      .get('ragazza-nella-nebbia--donato-carrisi--audiobook--fr')
    expect(release?.checkedAt).toEqual(checkedAt)
    expect(release?.descriptions).toEqual({
      fr: {
        description: description('La ragazza nella nebbia'),
        describedAt,
        describedFrom: 'ragazza-nella-nebbia~it',
      },
    })
    expect(fake.snapshot('edition-watches').size).toBe(0)
    expect(fake.snapshot('release-descriptions').size).toBe(0)
  })

  test('gives a described saga volume a release of its own, and drops the projections', async () => {
    fake.seed('saga-watches', 'red-rising--fr', {
      key: 'red-rising--fr',
      seriesId: 'red-rising--brown-pierce',
      name: 'Red Rising',
      author: 'Pierce Brown',
      language: 'fr',
      checkedAt,
      volumes: [
        { number: 7, title: 'Red God' },
        { number: 8, title: 'Nobody described' },
      ],
    })
    fake.seed('release-descriptions', 'red-god~pierce-brown~book~fr~7~fr', {
      description: description('Red God'),
      describedAt,
    })
    fake.seed('discovery-projections', 'u~book', { rows: 'x' })
    fake.seed('edition-pass', 'hourly', { entries: [] })

    await releasesHoldTheirDescriptions.migrate({ db: fakeDb() })

    const releases = fake.snapshot('releases')
    expect([...releases.keys()]).toEqual(['red-god--pierce-brown--book--fr'])
    expect(releases.get('red-god--pierce-brown--book--fr')).toMatchObject({
      title: 'Red God',
      series: { name: 'Red Rising', volume: 7 },
      descriptions: { fr: { describedFrom: 'red-god~fr' } },
    })
    expect(fake.snapshot('discovery-projections').size).toBe(0)
    expect(fake.snapshot('edition-pass').size).toBe(0)
    expect(fake.snapshot('saga-watches').size).toBe(1)
  })
})
