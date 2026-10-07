import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { alertsNoDeviceHeard } = await import(
  '~/system/migration/migrations/019-alerts-no-device-heard'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

describe('the alerts no device heard', () => {
  test('are put back for the readers who want them, settings or not', async () => {
    fake.seed('notification-settings', 'bob', { userId: 'bob', alerts: ['translation', 'digest'] })
    fake.seed('discovery-readers', 'bob', {
      userId: 'bob',
      notified: ['a--3'],
      announced: ['a--4'],
    })
    fake.seed('discovery-readers', 'ann', { userId: 'ann', notified: ['a--3'], announced: [] })

    const result = await alertsNoDeviceHeard.migrate({ db: fakeDb() })

    expect(result).toEqual({ ok: true, transformed: 2 })
    expect(fake.data('discovery-readers', 'bob')).toMatchObject({ notified: [], announced: [] })
    expect(fake.data('discovery-readers', 'ann')?.notified).toEqual([])
  })

  test('stay settled for an alert the reader switched off', async () => {
    fake.seed('notification-settings', 'bob', { userId: 'bob', alerts: ['digest'] })
    fake.seed('discovery-readers', 'bob', {
      userId: 'bob',
      notified: ['a--3'],
      announced: ['a--4'],
    })
    fake.seed('awaited-editions', 'bob--w', { userId: 'bob', notifiedAt: new Date('2026-10-01') })

    await alertsNoDeviceHeard.migrate({ db: fakeDb() })

    expect(fake.data('discovery-readers', 'bob')).toMatchObject({
      notified: ['a--3'],
      announced: [],
    })
    expect(fake.data('awaited-editions', 'bob--w')?.notifiedAt).toBeDefined()
  })

  test('put an awaited edition back, keeping the rest of it', async () => {
    fake.seed('awaited-editions', 'ann--w', {
      userId: 'ann',
      watchKey: 'w',
      notifiedAt: new Date('2026-10-01'),
    })
    fake.seed('awaited-editions', 'ann--v', { userId: 'ann', watchKey: 'v' })

    const result = await alertsNoDeviceHeard.migrate({ db: fakeDb() })

    expect(result).toEqual({ ok: true, transformed: 1 })
    expect(fake.data('awaited-editions', 'ann--w')).toEqual({ userId: 'ann', watchKey: 'w' })
  })
})
