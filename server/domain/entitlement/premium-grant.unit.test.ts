import { describe, expect, test } from 'bun:test'
import {
  earnsPremiumWelcome,
  isGrantActive,
  needsTesterCheck,
  normalizedEmail,
} from '~/domain/entitlement/business-rules'
import type { Entitlement, PremiumGrant } from '~/domain/entitlement/types'
import type { UserId } from '~/domain/shared/types'

const grant = (active: boolean, checkedAt: Date): PremiumGrant => ({
  userId: 'u1' as UserId,
  source: 'testflight',
  active,
  checkedAt,
})

describe('a TestFlight grant', () => {
  const now = new Date('2026-11-28T12:00:00.000Z')

  test('is Premium while App Store Connect last said the account is a tester', () => {
    expect(isGrantActive(grant(true, now))).toBe(true)
    expect(isGrantActive(grant(false, now))).toBe(false)
    expect(isGrantActive(undefined)).toBe(false)
  })

  test('asks App Store Connect for an account never checked', () => {
    expect(needsTesterCheck(undefined, now)).toBe(true)
  })

  test('holds the answer a day, tester or not', () => {
    const anHourAgo = new Date('2026-11-28T11:00:00.000Z')
    const aDayAgo = new Date('2026-11-27T12:00:00.000Z')
    expect(needsTesterCheck(grant(true, anHourAgo), now)).toBe(false)
    expect(needsTesterCheck(grant(false, anHourAgo), now)).toBe(false)
    expect(needsTesterCheck(grant(true, aDayAgo), now)).toBe(true)
  })
})

describe('a tester’s email', () => {
  test('compares without case or surrounding space', () => {
    expect(normalizedEmail('  Reader@Example.COM ')).toBe('reader@example.com')
  })
})

describe('the Premium welcome', () => {
  const entitlement = (overrides: Partial<Entitlement> = {}): Entitlement => ({
    userId: 'u1' as UserId,
    productId: 'com.polyforms.shiori.app.premium.yearly' as Entitlement['productId'],
    originalTransactionId: '1' as Entitlement['originalTransactionId'],
    appAccountToken: 'token' as Entitlement['appAccountToken'],
    expiresAt: new Date('2099-01-01T00:00:00.000Z'),
    updatedAt: new Date('2026-11-01T00:00:00.000Z'),
    ...overrides,
  })
  const now = new Date('2026-11-28T00:00:00.000Z')

  test('is earned by a paid Production period', () => {
    expect(earnsPremiumWelcome(entitlement(), now)).toBe(true)
  })

  test('is never earned in the Sandbox, which nobody pays', () => {
    expect(earnsPremiumWelcome(entitlement({ sandbox: true }), now)).toBe(false)
  })
})
