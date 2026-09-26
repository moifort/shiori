import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { discoveryReplacesDiscover } = await import(
  '~/system/migration/migrations/009-discovery-replaces-discover'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

describe('rebuilding Découvrir as its own domain', () => {
  test('drops the old feeds, watches and previews, and keeps the catalogues', async () => {
    fake.seed('discover', 'reader', { userId: 'reader', dated: [] })
    fake.seed('release-watches', 'series--carl--x--fr', { editions: [] })
    fake.seed('book-previews', 'carl-4--fr', { key: 'carl-4--fr' })
    fake.seed('series', 'carl--x', { id: 'carl--x', volumes: [] })

    const result = await discoveryReplacesDiscover.migrate({ db: fakeDb() })

    expect(result).toEqual({ ok: true, transformed: 3 })
    expect(fake.data('discover', 'reader')).toBeNull()
    expect(fake.data('release-watches', 'series--carl--x--fr')).toBeNull()
    expect(fake.data('book-previews', 'carl-4--fr')).toBeNull()
    expect(fake.data('series', 'carl--x')).not.toBeNull()
  })
})
