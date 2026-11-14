import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { createApp, toWebHandler } from 'h3'
import type { UserId } from '~/domain/shared/types'
import type { AppleNotification, AppleTransaction } from '~/system/apple/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/config/index', () => ({ config: () => ({ premiumUserIds: [] }) }))

// The signature check is Apple's library against real certificates; the route
// is tested against what a payload verifies to.
let verified: AppleNotification | 'invalid-signature' = 'invalid-signature'
mock.module('~/system/apple', () => ({
  Apple: {
    verifyTransaction: async () => 'invalid-signature',
    verifyNotification: async () => verified,
  },
}))

const { default: handler } = await import('~/routes/apple/notifications.post')
const { EntitlementCommand } = await import('~/domain/entitlement/command')
const { EntitlementQuery } = await import('~/domain/entitlement/query')

const reader = 'reader-1' as UserId

const aTransaction = (
  overrides: Partial<AppleTransaction> = {},
): AppleTransaction & { expiresAt: Date; appAccountToken: string } => ({
  productId: 'com.polyforms.shiori.app.premium.yearly',
  originalTransactionId: '2000000900000001',
  appAccountToken: EntitlementQuery.tokenFor(reader) as string,
  expiresAt: new Date('2099-01-01T00:00:00.000Z'),
  ...overrides,
})

const post = (body: unknown) =>
  toWebHandler(createApp().use('/apple/notifications', handler))(
    new Request('http://localhost/apple/notifications', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
    }),
  )

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
  verified = 'invalid-signature'
})

describe('the App Store notification webhook', () => {
  test('applies a renewal to the account it names', async () => {
    await EntitlementCommand.record(reader, aTransaction())
    verified = {
      type: 'DID_RENEW',
      transaction: aTransaction({ expiresAt: new Date('2100-01-01T00:00:00.000Z') }),
    }

    const response = await post({ signedPayload: 'signed' })

    expect(response.status).toBe(200)
    expect(await response.json()).toEqual({ status: 'applied' })
    expect((await EntitlementQuery.of(reader))?.expiresAt).toEqual(
      new Date('2100-01-01T00:00:00.000Z'),
    )
  })

  test('acknowledges a notification for an account never recorded', async () => {
    verified = { type: 'DID_RENEW', transaction: aTransaction() }

    const response = await post({ signedPayload: 'signed' })

    expect(response.status).toBe(200)
    expect(await response.json()).toEqual({ status: 'ignored' })
    expect(fake.snapshot('entitlements').size).toBe(0)
  })

  test('refuses a payload Apple did not sign', async () => {
    const response = await post({ signedPayload: 'forged' })

    expect(response.status).toBe(401)
  })

  test('refuses a body without a payload', async () => {
    const response = await post({})

    expect(response.status).toBe(400)
  })
})
