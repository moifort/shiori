import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { watchesOlderThanTheirCatalogue } = await import(
  '~/system/migration/migrations/011-watches-older-than-their-catalogue'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

describe('watches older than their catalogue', () => {
  test('are dropped, so their dates reach the catalogue on the next look', async () => {
    fake.seed('series', 'carl', { id: 'carl', catalogedAt: new Date('2026-09-27T04:46:00Z') })
    fake.seed('series', 'dune', { id: 'dune', catalogedAt: new Date('2026-09-20T10:00:00Z') })
    fake.seed('saga-watches', 'carl--fr', {
      seriesId: 'carl',
      checkedAt: new Date('2026-09-26T14:15:00Z'),
    })
    fake.seed('saga-watches', 'dune--fr', {
      seriesId: 'dune',
      checkedAt: new Date('2026-09-26T14:15:00Z'),
    })
    // A saga nobody catalogued keeps its watch: there is nothing to write into.
    fake.seed('saga-watches', 'hyperion--fr', {
      seriesId: 'hyperion',
      checkedAt: new Date('2026-09-26T14:15:00Z'),
    })

    const result = await watchesOlderThanTheirCatalogue.migrate({ db: fakeDb() })

    expect(result).toEqual({ ok: true, transformed: 1 })
    expect(fake.data('saga-watches', 'carl--fr')).toBeNull()
    expect(fake.data('saga-watches', 'dune--fr')).not.toBeNull()
    expect(fake.data('saga-watches', 'hyperion--fr')).not.toBeNull()
  })
})
