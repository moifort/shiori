import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import type { AppleNotification, AppleTransaction } from '~/system/apple/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

// Apple's verification is a signature check against real certificates; the domain
// is tested against what it decodes to, not against Apple's cryptography.
let verifiedTransaction: AppleTransaction | 'invalid-signature' = 'invalid-signature'
let verifiedNotification: AppleNotification | 'invalid-signature' = 'invalid-signature'

mock.module('~/system/apple', () => ({
  Apple: {
    verifyTransaction: async () => verifiedTransaction,
    verifyNotification: async () => verifiedNotification,
  },
}))

// `config()` reads Nitro's runtime config, which only exists inside a request.
let compedUserIds: string[] = []
mock.module('~/system/config/index', () => ({
  config: () => ({ premiumUserIds: compedUserIds }),
}))

const { EntitlementUseCase } = await import('~/domain/entitlement/use-case')
const { EntitlementQuery } = await import('~/domain/entitlement/query')

const user = (id: string) => id as UserId

// The token the purchase must carry to name this account, derived the same way
// the app is told to derive it.
const tokenOf = (id: string) => EntitlementQuery.tokenFor(user(id)) as string

const aTransaction = (overrides: Partial<AppleTransaction> = {}): AppleTransaction => ({
  productId: 'com.polyforms.vinarium.app.premium.yearly',
  originalTransactionId: '2000000900000001',
  appAccountToken: tokenOf('u1'),
  expiresAt: new Date('2099-01-01T00:00:00.000Z'),
  ...overrides,
})

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
  verifiedTransaction = 'invalid-signature'
  verifiedNotification = 'invalid-signature'
  compedUserIds = []
})

describe('syncing a purchase the app hands over', () => {
  test('records the entitlement and turns the account premium', async () => {
    verifiedTransaction = aTransaction()

    const result = await EntitlementUseCase.sync(user('u1'), 'signed-jws')

    expect(result).toMatchObject({
      userId: 'u1',
      productId: 'com.polyforms.vinarium.app.premium.yearly',
      originalTransactionId: '2000000900000001',
    })
    expect(await EntitlementQuery.planOf(user('u1'))).toBe('premium')
  })

  test('refuses a transaction Apple did not sign', async () => {
    verifiedTransaction = 'invalid-signature'

    expect(await EntitlementUseCase.sync(user('u1'), 'forged')).toBe('invalid-transaction')
    expect(fake.snapshot('entitlements').size).toBe(0)
  })

  test('refuses a purchase that names another account', async () => {
    verifiedTransaction = aTransaction({ appAccountToken: tokenOf('someone-else') })

    expect(await EntitlementUseCase.sync(user('u1'), 'signed-jws')).toBe('transaction-not-yours')
    expect(fake.snapshot('entitlements').size).toBe(0)
  })

  test('refuses a purchase that grants no time', async () => {
    verifiedTransaction = aTransaction({ expiresAt: undefined })

    expect(await EntitlementUseCase.sync(user('u1'), 'signed-jws')).toBe('invalid-transaction')
  })

  test('overwrites in place on a renewal rather than storing a second entitlement', async () => {
    verifiedTransaction = aTransaction({ expiresAt: new Date('2027-01-01T00:00:00.000Z') })
    await EntitlementUseCase.sync(user('u1'), 'signed-jws')

    verifiedTransaction = aTransaction({ expiresAt: new Date('2028-01-01T00:00:00.000Z') })
    await EntitlementUseCase.sync(user('u1'), 'signed-jws')

    expect(fake.snapshot('entitlements').size).toBe(1)
    expect((await EntitlementQuery.of(user('u1')))?.expiresAt).toEqual(
      new Date('2028-01-01T00:00:00.000Z'),
    )
  })
})

describe('applying what Apple pushed to the webhook', () => {
  test('renews the entitlement of the account the token names', async () => {
    verifiedTransaction = aTransaction({ expiresAt: new Date('2027-01-01T00:00:00.000Z') })
    await EntitlementUseCase.sync(user('u1'), 'signed-jws')

    verifiedNotification = {
      type: 'DID_RENEW',
      transaction: aTransaction({ expiresAt: new Date('2028-01-01T00:00:00.000Z') }),
    }

    expect(await EntitlementUseCase.applyNotification('signed-payload')).toBe('applied')
    expect((await EntitlementQuery.of(user('u1')))?.expiresAt).toEqual(
      new Date('2028-01-01T00:00:00.000Z'),
    )
  })

  test('ends Premium on a refund, whatever the expiry still says', async () => {
    verifiedTransaction = aTransaction()
    await EntitlementUseCase.sync(user('u1'), 'signed-jws')

    verifiedNotification = {
      type: 'REFUND',
      transaction: aTransaction({ revokedAt: new Date('2026-07-21T00:00:00.000Z') }),
    }
    await EntitlementUseCase.applyNotification('signed-payload')

    expect(await EntitlementQuery.planOf(user('u1'))).toBe('free')
  })

  test('acknowledges and drops a notification for an account we never recorded', async () => {
    verifiedNotification = { type: 'DID_RENEW', transaction: aTransaction() }

    expect(await EntitlementUseCase.applyNotification('signed-payload')).toBe('ignored')
    expect(fake.snapshot('entitlements').size).toBe(0)
  })

  test('refuses a notification Apple did not sign', async () => {
    verifiedNotification = 'invalid-signature'

    expect(await EntitlementUseCase.applyNotification('forged')).toBe('invalid-notification')
  })
})

describe('reading the plan', () => {
  test('is free for an account that never bought anything', async () => {
    expect(await EntitlementQuery.planOf(user('u1'))).toBe('free')
  })

  test('is premium for a comped account, which never bought anything', async () => {
    compedUserIds = ['u1']

    expect(await EntitlementQuery.planOf(user('u1'))).toBe('premium')
    expect(await EntitlementQuery.planOf(user('u2'))).toBe('free')
  })

  test('costs one document read, however many times it is asked in a request', async () => {
    verifiedTransaction = aTransaction()
    await EntitlementUseCase.sync(user('u1'), 'signed-jws')

    const before = fake.docReads
    await EntitlementQuery.planOf(user('u1'))
    await EntitlementQuery.planOf(user('u1'))

    expect(fake.docReads - before).toBe(1)
    expect(fake.queryReads).toBe(0)
  })
})
