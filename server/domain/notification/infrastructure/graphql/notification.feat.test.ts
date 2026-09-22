import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { graphql } from 'graphql'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { schema } = await import('~/domain/shared/graphql/schema')

const reader = 'reader' as UserId
const run = (source: string) =>
  graphql({ schema, source, contextValue: { event: {}, userId: reader } })
const token = 'ab'.repeat(32)

beforeEach(() => {
  resetFakeFirestore()
})

describe('the notification settings', () => {
  test('start with every alert off and no device', async () => {
    const result = await run('{ notificationSettings { alerts { kind enabled } deviceCount } }')

    expect(result.errors).toBeUndefined()
    expect(result.data?.notificationSettings).toEqual({
      alerts: [
        { kind: 'SERIES_VOLUME', enabled: false },
        { kind: 'TRANSLATION', enabled: false },
        { kind: 'AUDIBLE_RELEASE', enabled: false },
        { kind: 'AUTHOR_RELEASE', enabled: false },
      ],
      deviceCount: 0,
    })
  })

  test('remember a device once and the alerts switched on', async () => {
    await run(
      `mutation { registerDevice(token: "${token}", environment: PRODUCTION) { deviceCount } }`,
    )
    await run(
      `mutation { registerDevice(token: "${token}", environment: PRODUCTION) { deviceCount } }`,
    )
    const result = await run(
      'mutation { setAlert(kind: TRANSLATION, enabled: true) { deviceCount alerts { kind enabled } } }',
    )

    expect(result.data?.setAlert).toMatchObject({
      deviceCount: 1,
      alerts: expect.arrayContaining([{ kind: 'TRANSLATION', enabled: true }]),
    })
  })

  test('forget a device the reader signed out of', async () => {
    await run(
      `mutation { registerDevice(token: "${token}", environment: SANDBOX) { deviceCount } }`,
    )
    const result = await run(`mutation { unregisterDevice(token: "${token}") { deviceCount } }`)

    expect(result.data?.unregisterDevice).toEqual({ deviceCount: 0 })
  })

  test('refuse a token that is not one', async () => {
    const result = await run(
      'mutation { registerDevice(token: "hello", environment: PRODUCTION) { deviceCount } }',
    )

    expect(result.errors?.[0]?.extensions?.code).toBe('BAD_USER_INPUT')
  })
})
