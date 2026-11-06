import { describe, expect, test } from 'bun:test'
import { parseSubscription } from './subscription'

const now = new Date('2026-11-06T10:00:00.000Z')

describe('reading what Google answered for a purchase token', () => {
  test('keeps the plan, the paid period and the account it was bought for', () => {
    const subscription = parseSubscription(
      'token-1',
      {
        startTime: '2026-11-01T09:00:00.000Z',
        subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
        acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING',
        externalAccountIdentifiers: { obfuscatedExternalAccountId: 'account-token' },
        lineItems: [
          {
            productId: 'com.polyforms.shiori.app.premium.yearly',
            expiryTime: '2027-11-01T09:00:00.000Z',
          },
        ],
      },
      now,
    )

    expect(subscription).toMatchObject({
      productId: 'com.polyforms.shiori.app.premium.yearly',
      purchaseToken: 'token-1',
      accountToken: 'account-token',
      needsAcknowledgement: true,
    })
    expect(subscription?.expiresAt).toEqual(new Date('2027-11-01T09:00:00.000Z'))
    expect(subscription?.startedAt).toEqual(new Date('2026-11-01T09:00:00.000Z'))
    expect(subscription?.revokedAt).toBeUndefined()
  })

  test('takes the line item that runs the longest', () => {
    const subscription = parseSubscription(
      'token-1',
      {
        lineItems: [
          { productId: 'monthly', expiryTime: '2026-12-01T00:00:00.000Z' },
          { productId: 'yearly', expiryTime: '2027-11-01T00:00:00.000Z' },
        ],
      },
      now,
    )

    expect(subscription?.productId).toBe('yearly')
  })

  test('reads a subscription ended before its paid period as revoked', () => {
    const subscription = parseSubscription(
      'token-1',
      {
        subscriptionState: 'SUBSCRIPTION_STATE_EXPIRED',
        lineItems: [{ productId: 'yearly', expiryTime: '2027-11-01T00:00:00.000Z' }],
      },
      now,
    )

    expect(subscription?.revokedAt).toEqual(now)
  })

  test('does not revoke a subscription that simply ran out', () => {
    const subscription = parseSubscription(
      'token-1',
      {
        subscriptionState: 'SUBSCRIPTION_STATE_EXPIRED',
        lineItems: [{ productId: 'yearly', expiryTime: '2026-10-01T00:00:00.000Z' }],
      },
      now,
    )

    expect(subscription?.revokedAt).toBeUndefined()
  })

  test('answers nothing for a purchase that names no product', () => {
    expect(parseSubscription('token-1', { lineItems: [] }, now)).toBeUndefined()
  })
})
