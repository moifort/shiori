import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { discoverIsTranslations } = await import(
  '~/system/migration/migrations/006-discover-is-translations'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const run = () => discoverIsTranslations.migrate({ db: fakeDb() })

describe('turning Découvrir into translations', () => {
  test('drops the old shelves and the shared lists behind them', async () => {
    fake.seed('discover', 'reader', { userId: 'reader', offTrail: [] })
    fake.seed('release-watches', 'series--cradle', { releases: [] })
    fake.seed('genre-lists', 'fantasy--fr', { awards: [] })
    fake.seed('books', 'kept', { userId: 'reader', title: 'Cradle' })

    await run()

    expect(fake.data('discover', 'reader')).toBeNull()
    expect(fake.data('release-watches', 'series--cradle')).toBeNull()
    expect(fake.data('genre-lists', 'fantasy--fr')).toBeNull()
    expect(fake.data('books', 'kept')).not.toBeNull()
  })

  test('keeps the translation alert alone, switched on', async () => {
    fake.seed('notification-settings', 'off', { userId: 'off', devices: [], alerts: [] })
    fake.seed('notification-settings', 'sagas', {
      userId: 'sagas',
      devices: [],
      alerts: ['series-volume', 'author-release'],
    })

    const result = await run()

    expect(result).toEqual({ ok: true, transformed: 2 })
    expect(fake.data('notification-settings', 'off')?.alerts).toEqual(['translation'])
    expect(fake.data('notification-settings', 'sagas')?.alerts).toEqual(['translation'])
  })
})
