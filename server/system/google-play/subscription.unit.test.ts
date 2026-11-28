import { describe, expect, test } from 'bun:test'
import { inFreeTrial, parseSubscription } from './subscription'

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

  test('reads a line item in its free trial phase as a trial', () => {
    const subscription = parseSubscription(
      'token-1',
      {
        lineItems: [
          {
            productId: 'yearly',
            expiryTime: '2026-12-06T00:00:00.000Z',
            offerDetails: { offerId: 'free-month' },
            offerPhase: { freeTrial: {} },
          },
        ],
      },
      now,
    )

    expect(subscription?.freeTrial).toBe(true)
  })

  test('reads the base price phase of the same offer as paid', () => {
    const subscription = parseSubscription(
      'token-1',
      {
        lineItems: [
          {
            productId: 'yearly',
            expiryTime: '2027-12-06T00:00:00.000Z',
            offerDetails: { offerId: 'free-month' },
            offerPhase: { basePrice: {} },
          },
        ],
      },
      now,
    )

    expect(subscription?.freeTrial).toBeUndefined()
  })

  test('reads the base plan bought with no offer as paid', () => {
    expect(inFreeTrial({ productId: 'yearly' })).toBe(false)
  })

  test('reads an offer that does not say its phase as a trial, to grant nothing too early', () => {
    expect(inFreeTrial({ productId: 'yearly', offerDetails: { offerId: 'free-month' } })).toBe(true)
  })

  test('marks a license tester’s purchase, which Play charges nothing for', () => {
    const subscription = parseSubscription(
      'token',
      {
        testPurchase: {},
        lineItems: [
          {
            productId: 'com.polyforms.shiori.app.premium.yearly',
            expiryTime: '2099-01-01T00:00:00Z',
          },
        ],
      },
      new Date('2026-11-28T00:00:00Z'),
    )
    expect(subscription?.sandbox).toBe(true)
  })
})
