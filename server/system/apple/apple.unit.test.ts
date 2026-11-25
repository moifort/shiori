import { beforeEach, describe, expect, mock, test } from 'bun:test'

// The real config reads Nitro's runtime config, which only exists in a request.
let appleEnvironment: string | undefined
mock.module('~/system/config/index', () => ({
  config: () => ({ appleEnvironment }),
}))

const { Apple, isFreeTrial, verificationEnvironments } = await import('~/system/apple')
const { Environment, OfferDiscountType, OfferType } = await import(
  '@apple/app-store-server-library'
)

beforeEach(() => {
  appleEnvironment = undefined
})

describe('which App Store a signature may come from', () => {
  // The bug this guards: while the numeric App Store id was an operational
  // setting, forgetting to set it silently pinned verification to Sandbox, and
  // every real App Store purchase came back unverifiable. The id is a published,
  // permanent fact about the app, so Production is always among the environments
  // tried — no deployment can be missing it.
  test('tries Production with nothing configured at all', () => {
    expect(verificationEnvironments()).toEqual([Environment.PRODUCTION, Environment.SANDBOX])
  })

  test('honours a pinned environment', () => {
    appleEnvironment = 'Sandbox'

    expect(verificationEnvironments()).toEqual([Environment.SANDBOX])
  })
})

describe('verifying something Apple did not sign', () => {
  test('answers invalid-signature for a payload that is not a JWS at all', async () => {
    expect(await Apple.verifyTransaction('not-a-jws')).toBe('invalid-signature')
    expect(await Apple.verifyNotification('not-a-jws')).toBe('invalid-signature')
  })

  test('answers invalid-signature with a pinned environment', async () => {
    appleEnvironment = 'Sandbox'

    expect(await Apple.verifyTransaction('not-a-jws')).toBe('invalid-signature')
  })

  test('refuses a forged payload rather than decoding it', async () => {
    // A syntactically valid JWS whose signature chains to nothing of Apple's.
    const forged = [
      Buffer.from(JSON.stringify({ alg: 'ES256', x5c: [] })).toString('base64url'),
      Buffer.from(
        JSON.stringify({ productId: 'com.polyforms.shiori.app.premium.yearly' }),
      ).toString('base64url'),
      'c2lnbmF0dXJl',
    ].join('.')

    expect(await Apple.verifyTransaction(forged)).toBe('invalid-signature')
  })
})

describe('telling a free trial from a paid period', () => {
  test('reads an introductory free trial as a trial', () => {
    expect(
      isFreeTrial({
        offerType: OfferType.INTRODUCTORY_OFFER,
        offerDiscountType: OfferDiscountType.FREE_TRIAL,
      }),
    ).toBe(true)
  })

  test('reads a renewal carrying no offer as paid', () => {
    expect(isFreeTrial({})).toBe(false)
  })

  test('reads a paid introductory price as paid', () => {
    expect(
      isFreeTrial({
        offerType: OfferType.INTRODUCTORY_OFFER,
        offerDiscountType: OfferDiscountType.PAY_UP_FRONT,
      }),
    ).toBe(false)
  })

  test('reads an introductory offer naming no discount as a trial, the only one sold', () => {
    expect(isFreeTrial({ offerType: OfferType.INTRODUCTORY_OFFER })).toBe(true)
  })
})
