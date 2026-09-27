import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { digestAlertStartsOn } = await import(
  '~/system/migration/migrations/012-digest-alert-starts-on'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

describe('the digest alert', () => {
  test('starts on for the readers who hear of new volumes, off for the ones who hear nothing', async () => {
    fake.seed('notification-settings', 'bob', { userId: 'bob', alerts: ['translation'] })
    fake.seed('notification-settings', 'ann', { userId: 'ann', alerts: [] })

    const result = await digestAlertStartsOn.migrate({ db: fakeDb() })

    expect(result).toEqual({ ok: true, transformed: 1 })
    expect(fake.data('notification-settings', 'bob')?.alerts).toEqual(['translation', 'digest'])
    expect(fake.data('notification-settings', 'ann')?.alerts).toEqual([])
  })
})
