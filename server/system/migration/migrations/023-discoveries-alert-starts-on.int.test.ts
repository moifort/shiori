import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { discoveriesAlertStartsOn } = await import(
  '~/system/migration/migrations/023-discoveries-alert-starts-on'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

describe('the discoveries alert', () => {
  test('starts on for the readers who hear something, off for the ones who hear nothing', async () => {
    fake.seed('notification-settings', 'bob', { userId: 'bob', alerts: ['translation', 'digest'] })
    fake.seed('notification-settings', 'cat', { userId: 'cat', alerts: ['digest'] })
    fake.seed('notification-settings', 'ann', { userId: 'ann', alerts: [] })

    const result = await discoveriesAlertStartsOn.migrate({ db: fakeDb() })

    expect(result).toEqual({ ok: true, transformed: 2 })
    expect(fake.data('notification-settings', 'bob')?.alerts).toEqual([
      'translation',
      'digest',
      'discoveries',
    ])
    expect(fake.data('notification-settings', 'cat')?.alerts).toEqual(['digest', 'discoveries'])
    expect(fake.data('notification-settings', 'ann')?.alerts).toEqual([])
  })

  test('is left as it is for a reader who has it already', async () => {
    fake.seed('notification-settings', 'bob', { userId: 'bob', alerts: ['discoveries'] })

    expect(await discoveriesAlertStartsOn.migrate({ db: fakeDb() })).toEqual({
      ok: true,
      transformed: 0,
    })
  })
})
