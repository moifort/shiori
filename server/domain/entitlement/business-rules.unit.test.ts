import { describe, expect, it } from 'bun:test'
import {
  appAccountToken,
  isActive,
  planOf,
  reconciled,
  runningEntitlementOf,
} from '~/domain/entitlement/business-rules'
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
    expect(planOf([], now)).toBe('free')
  })

  it('is premium while the entitlement is active', () => {
    expect(planOf([anEntitlement()], now)).toBe('premium')
  })

  it('is free once it has expired or been revoked', () => {
    expect(planOf([anEntitlement({ expiresAt: new Date('2026-01-01T00:00:00.000Z') })], now)).toBe(
      'free',
    )
    expect(planOf([anEntitlement({ revokedAt: now })], now)).toBe('free')
  })

  it('is premium while either store s entitlement is active, the other lapsed', () => {
    const lapsedAppStore = anEntitlement({ expiresAt: new Date('2026-01-01T00:00:00.000Z') })
    const activePlay = anEntitlement({ store: 'google-play' })
    expect(planOf([lapsedAppStore, activePlay], now)).toBe('premium')
  })
})

describe('the entitlement the screens describe', () => {
  const now = new Date('2026-07-21T00:00:00.000Z')

  it('is the active one, whatever ended later elsewhere', () => {
    const refunded = anEntitlement({ revokedAt: now, expiresAt: new Date('2030-01-01T00:00:00Z') })
    const active = anEntitlement({ store: 'google-play' })
    expect(runningEntitlementOf([refunded, active], now)).toBe(active)
  })

  it('is the one that ended last when none runs', () => {
    const older = anEntitlement({ expiresAt: new Date('2026-01-01T00:00:00.000Z') })
    const newer = anEntitlement({ expiresAt: new Date('2026-06-01T00:00:00.000Z') })
    expect(runningEntitlementOf([older, newer], now)).toBe(newer)
    expect(runningEntitlementOf([], now)).toBeUndefined()
  })
})

describe('what is recorded when a store vouches again', () => {
  const signed = (iso: string) => new Date(iso)

  it('records a first entitlement as it is', () => {
    const incoming = anEntitlement({ signedAt: signed('2026-07-01T00:00:00Z') })
    expect(reconciled(undefined, incoming)).toBe(incoming)
  })

  it('keeps the stored one over a payload signed before it', () => {
    const stored = anEntitlement({ signedAt: signed('2026-07-10T00:00:00Z') })
    const replayed = anEntitlement({ signedAt: signed('2026-07-01T00:00:00Z') })
    expect(reconciled(stored, replayed)).toBe('stale')
  })

  it('keeps the stored one over a payload that carries no signing date', () => {
    const stored = anEntitlement({ signedAt: signed('2026-07-10T00:00:00Z') })
    expect(reconciled(stored, anEntitlement())).toBe('stale')
  })

  it('takes a payload signed later, a renewal', () => {
    const stored = anEntitlement({ signedAt: signed('2026-07-01T00:00:00Z') })
    const renewal = anEntitlement({ signedAt: signed('2026-08-01T00:00:00Z') })
    expect(reconciled(stored, renewal)).toBe(renewal)
  })

  it('keeps a refund over a payload of the same chain signed before it', () => {
    const revokedAt = signed('2026-07-10T00:00:00Z')
    const stored = anEntitlement({ revokedAt, signedAt: revokedAt })
    // Recorded before the signing dates were kept: only the refund date orders it.
    const legacy = { ...stored, signedAt: undefined }
    const replayed = anEntitlement({ signedAt: signed('2026-07-01T00:00:00Z') })
    expect(reconciled(stored, replayed)).toBe('stale')
    expect(reconciled(legacy, replayed)).toEqual({ ...replayed, revokedAt })
  })

  it('lifts a refund only for a payload signed after it, a refund reversed', () => {
    const revokedAt = signed('2026-07-10T00:00:00Z')
    const stored = anEntitlement({ revokedAt })
    const reversed = anEntitlement({ signedAt: signed('2026-07-12T00:00:00Z') })
    expect(reconciled(stored, reversed)).toBe(reversed)
  })

  it('does not carry a refund over to another chain', () => {
    const stored = anEntitlement({ revokedAt: signed('2026-07-10T00:00:00Z') })
    const resubscribed = anEntitlement({
      originalTransactionId: OriginalTransactionId('2000000900000999'),
      signedAt: signed('2026-07-01T00:00:00Z'),
    })
    expect(reconciled(stored, resubscribed)).toBe(resubscribed)
  })
})
