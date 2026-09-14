import { describe, expect, it } from 'bun:test'
import { appAccountToken, isActive, planOf } from '~/domain/entitlement/business-rules'
import { AppAccountToken, OriginalTransactionId, ProductId } from '~/domain/entitlement/primitives'
import type { Entitlement } from '~/domain/entitlement/types'
import { UserId } from '~/domain/shared/primitives'

const anEntitlement = (overrides: Partial<Entitlement> = {}): Entitlement => ({
  userId: UserId('user-1'),
  productId: ProductId('com.polyforms.vinarium.app.premium.yearly'),
  originalTransactionId: OriginalTransactionId('2000000900000001'),
  appAccountToken: AppAccountToken('20099a54-f027-5426-b2f0-79d90a5050f1'),
  expiresAt: new Date('2027-01-01T00:00:00.000Z'),
  updatedAt: new Date('2026-07-21T00:00:00.000Z'),
  ...overrides,
})

describe('the account token a purchase must carry', () => {
  // A tripwire, not a behaviour test. These UUIDs are what every subscription
  // already sold is matched against: if this fails, the derivation changed and
  // every paying account silently lost its Premium. Restore the namespace and
  // the algorithm rather than updating the vector.
  it('is frozen forever', () => {
    expect(appAccountToken(UserId('user-1')) as string).toBe('20099a54-f027-5426-b2f0-79d90a5050f1')
    expect(appAccountToken(UserId('KyTjMU39NBhfakGxExfqLmC5OYU2')) as string).toBe(
      '7b756c48-654b-5be8-82bb-33f8cbee2a21',
    )
  })

  it('is a version-5 UUID', () => {
    const token = appAccountToken(UserId('user-1')) as string
    expect(token[14]).toBe('5')
    expect('89ab').toContain(token[19] as string)
  })

  it('is the same on every call, so a reinstall keeps its purchase', () => {
    expect(appAccountToken(UserId('user-1'))).toBe(appAccountToken(UserId('user-1')))
  })

  it('differs between accounts', () => {
    expect(appAccountToken(UserId('user-1'))).not.toBe(appAccountToken(UserId('user-2')))
  })
})

describe('whether the App Store still owes this account its Premium', () => {
  const now = new Date('2026-07-21T00:00:00.000Z')

  it('runs to the paid-for date', () => {
    expect(isActive(anEntitlement(), now)).toBe(true)
  })

  it('ends once the paid period has passed', () => {
    expect(isActive(anEntitlement({ expiresAt: new Date('2026-07-20T23:59:59.000Z') }), now)).toBe(
      false,
    )
  })

  it('ends on the spot when refunded, whatever the expiry still says', () => {
    expect(isActive(anEntitlement({ revokedAt: now }), now)).toBe(false)
  })
})

describe('the plan an account is on', () => {
  const now = new Date('2026-07-21T00:00:00.000Z')

  it('is free without an entitlement', () => {
    expect(planOf(undefined, now)).toBe('free')
  })

  it('is premium while the entitlement is active', () => {
    expect(planOf(anEntitlement(), now)).toBe('premium')
  })

  it('is free once it has expired or been revoked', () => {
    expect(planOf(anEntitlement({ expiresAt: new Date('2026-01-01T00:00:00.000Z') }), now)).toBe(
      'free',
    )
    expect(planOf(anEntitlement({ revokedAt: now }), now)).toBe('free')
  })
})
