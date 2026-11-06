import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import type { AppleNotification, AppleTransaction } from '~/system/apple/types'
import type { PlaySubscription } from '~/system/google-play/types'
import { fakeDb, resetFakeFirestore, startFakeRequest } from '~/test/fake-firestore'

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

// Google's answer for a purchase token, as the Play Developer API would give it.
let verifiedPlay: PlaySubscription | 'invalid-token' = 'invalid-token'
let acknowledged: string[] = []

mock.module('~/system/google-play', () => ({
  GooglePlay: {
    verifySubscription: async () => verifiedPlay,
    acknowledge: async (subscription: PlaySubscription) => {
      acknowledged.push(subscription.purchaseToken)
    },
  },
}))

// `config()` reads Nitro's runtime config, which only exists inside a request.
let compedUserIds: string[] = []
mock.module('~/system/config/index', () => ({
  config: () => ({ premiumUserIds: compedUserIds }),
}))

const { EntitlementUseCase } = await import('~/domain/entitlement/use-case')
const { EntitlementQuery } = await import('~/domain/entitlement/query')
const { QuotaCommand } = await import('~/domain/quota/command')
const { QuotaQuery } = await import('~/domain/quota/query')
const { PREMIUM_WELCOME_SCANS, WELCOME_SCANS } = await import('~/domain/quota/business-rules')

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
  verifiedPlay = 'invalid-token'
  acknowledged = []
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

  test('keeps when the chain began, the same on every renewal', async () => {
    const startedAt = new Date('2026-10-02T09:00:00.000Z')
    verifiedTransaction = aTransaction({ startedAt })
    await EntitlementUseCase.sync(user('u1'), 'signed-jws')

    expect((await EntitlementQuery.of(user('u1')))?.startedAt).toEqual(startedAt)
  })
})

describe('the scans handed to an account turning Premium', () => {
  const creditOf = async (id: string) => (await QuotaQuery.creditOf(user(id))).scans as number

  test('lands on top of what the account still held from its welcome', async () => {
    await QuotaCommand.grantWelcomeCredit(user('u1'))
    verifiedTransaction = aTransaction()

    await EntitlementUseCase.sync(user('u1'), 'signed-jws')

    expect(await creditOf('u1')).toBe(WELCOME_SCANS + PREMIUM_WELCOME_SCANS)
  })

  test('is handed once, however many launches sync the subscription again', async () => {
    verifiedTransaction = aTransaction()

    await Promise.all([
      EntitlementUseCase.sync(user('u1'), 'signed-jws'),
      EntitlementUseCase.sync(user('u1'), 'signed-jws'),
    ])
    await EntitlementUseCase.sync(user('u1'), 'signed-jws')

    expect(await creditOf('u1')).toBe(PREMIUM_WELCOME_SCANS)
  })

  test('is not handed again on a renewal, nor on subscribing again after a lapse', async () => {
    verifiedTransaction = aTransaction()
    await EntitlementUseCase.sync(user('u1'), 'signed-jws')
    verifiedNotification = {
      type: 'EXPIRED',
      transaction: aTransaction({ expiresAt: new Date('2026-01-01T00:00:00.000Z') }),
    }
    await EntitlementUseCase.applyNotification('signed-payload')

    verifiedTransaction = aTransaction({ expiresAt: new Date('2100-01-01T00:00:00.000Z') })
    await EntitlementUseCase.sync(user('u1'), 'signed-jws')

    expect(await creditOf('u1')).toBe(PREMIUM_WELCOME_SCANS)
  })

  test('is not handed for a subscription that has already run out', async () => {
    verifiedTransaction = aTransaction({ expiresAt: new Date('2026-01-01T00:00:00.000Z') })

    await EntitlementUseCase.sync(user('u1'), 'signed-jws')

    expect(await creditOf('u1')).toBe(0)
  })

  test('is handed to a subscriber recorded before it existed, on their next sync', async () => {
    verifiedTransaction = aTransaction()
    await EntitlementUseCase.sync(user('u1'), 'signed-jws')
    await fakeDb().collection('ai-credits').doc('u1').delete()

    await EntitlementUseCase.sync(user('u1'), 'signed-jws')

    expect(await creditOf('u1')).toBe(PREMIUM_WELCOME_SCANS)
  })

  test('is not handed for a purchase refused as another account s', async () => {
    verifiedTransaction = aTransaction({ appAccountToken: tokenOf('someone-else') })

    await EntitlementUseCase.sync(user('u1'), 'signed-jws')

    expect(await creditOf('u1')).toBe(0)
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
    startFakeRequest()

    const before = fake.docReads
    await EntitlementQuery.planOf(user('u1'))
    await EntitlementQuery.planOf(user('u1'))

    expect(fake.docReads - before).toBe(1)
    expect(fake.queryReads).toBe(0)
  })
})

const aPlayPurchase = (overrides: Partial<PlaySubscription> = {}): PlaySubscription => ({
  productId: 'com.polyforms.shiori.app.premium.yearly',
  purchaseToken: 'play-token-1',
  accountToken: tokenOf('u1'),
  expiresAt: new Date('2099-01-01T00:00:00.000Z'),
  needsAcknowledgement: true,
  ...overrides,
})

describe('syncing a Google Play purchase the Android app hands over', () => {
  test('records the entitlement as Google Play’s and turns the account premium', async () => {
    verifiedPlay = aPlayPurchase()

    const result = await EntitlementUseCase.syncPlay(user('u1'), 'play-token-1')

    expect(result).toMatchObject({
      userId: 'u1',
      productId: 'com.polyforms.shiori.app.premium.yearly',
      originalTransactionId: 'play-token-1',
      store: 'google-play',
    })
    expect(await EntitlementQuery.planOf(user('u1'))).toBe('premium')
  })

  test('acknowledges a purchase Google still waits on, and only that one', async () => {
    verifiedPlay = aPlayPurchase()
    await EntitlementUseCase.syncPlay(user('u1'), 'play-token-1')
    verifiedPlay = aPlayPurchase({ needsAcknowledgement: false })
    await EntitlementUseCase.syncPlay(user('u1'), 'play-token-1')

    expect(acknowledged).toEqual(['play-token-1'])
  })

  test('refuses a token Google does not know', async () => {
    expect(await EntitlementUseCase.syncPlay(user('u1'), 'made-up')).toBe('invalid-transaction')
    expect(fake.snapshot('entitlements').size).toBe(0)
  })

  test('refuses a purchase that names another account', async () => {
    verifiedPlay = aPlayPurchase({ accountToken: tokenOf('someone-else') })

    expect(await EntitlementUseCase.syncPlay(user('u1'), 'play-token-1')).toBe(
      'transaction-not-yours',
    )
    expect(fake.snapshot('entitlements').size).toBe(0)
    expect(acknowledged).toEqual([])
  })

  test('refuses a purchase made without an account', async () => {
    verifiedPlay = aPlayPurchase({ accountToken: undefined })

    expect(await EntitlementUseCase.syncPlay(user('u1'), 'play-token-1')).toBe(
      'invalid-transaction',
    )
  })

  test('hands the Premium welcome scans, as an App Store purchase does', async () => {
    verifiedPlay = aPlayPurchase()

    await EntitlementUseCase.syncPlay(user('u1'), 'play-token-1')

    expect((await QuotaQuery.creditOf(user('u1'))).scans as number).toBe(PREMIUM_WELCOME_SCANS)
  })

  test('reads a refunded purchase as free', async () => {
    verifiedPlay = aPlayPurchase({ revokedAt: new Date('2026-11-01T00:00:00.000Z') })

    await EntitlementUseCase.syncPlay(user('u1'), 'play-token-1')

    expect(await EntitlementQuery.planOf(user('u1'))).toBe('free')
  })
})
