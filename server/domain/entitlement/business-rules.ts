import { createHash } from 'node:crypto'
import { AppAccountToken as toAppAccountToken } from '~/domain/entitlement/primitives'
import type { AppAccountToken, Entitlement } from '~/domain/entitlement/types'
import type { Plan, UserId } from '~/domain/shared/types'

// The namespace the account token is derived in. Arbitrary but frozen forever:
// change it and every entitlement already sold stops matching its owner.
const TOKEN_NAMESPACE = 'bc4a0626-772c-4b01-a0ec-4d018ee55375'

const hexToBytes = (hex: string) => Buffer.from(hex.replaceAll('-', ''), 'hex')

// The UUID StoreKit must carry on a purchase for us to recognise whose it is.
// A version-5 UUID (RFC 4122: SHA-1 over namespace + name, with the version and
// variant bits forced) of the account's id — derived rather than stored, so it
// needs no write and is the same before and after a reinstall. One-way on
// purpose: the token travels through Apple's servers and reveals nothing about
// the account.
export const appAccountToken = (userId: UserId): AppAccountToken => {
  const hash = createHash('sha1')
    .update(hexToBytes(TOKEN_NAMESPACE))
    .update(Buffer.from(userId as string, 'utf8'))
    .digest()
  const bytes = Buffer.from(hash.subarray(0, 16))
  bytes[6] = ((bytes[6] as number) & 0x0f) | 0x50
  bytes[8] = ((bytes[8] as number) & 0x3f) | 0x80
  const hex = bytes.toString('hex')
  return toAppAccountToken(
    `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`,
  )
}

// Whether the App Store still owes this account its Premium. A refund revokes it
// on the spot; otherwise it runs to the paid-for date, and cancelling only stops
// the renewal. Cancelled today still means Premium until the end of the period:
// that is what was paid for.
export const isActive = (entitlement: Entitlement, now: Date): boolean =>
  entitlement.revokedAt === undefined && entitlement.expiresAt > now

// Whether an entitlement has earned the Premium welcome credit: Premium now, and paid for.
// A free trial is Premium without a payment, and the credit outlives the subscription, so
// handing it at the trial's start let anyone scan a whole library for nothing and cancel.
// The first paid period earns it; the grant's own once-only guard keeps every later renewal
// from earning it again.
export const earnsPremiumWelcome = (entitlement: Entitlement, now: Date): boolean =>
  isActive(entitlement, now) && entitlement.freeTrial !== true

// The plan an account is on: Premium while any of its entitlements — one per store — is
// active. None, expired, revoked: all are `free`. There is no other way to be Premium.
export const planOf = (entitlements: readonly Entitlement[], now: Date): Plan =>
  entitlements.some((entitlement) => isActive(entitlement, now)) ? 'premium' : 'free'

// The entitlement an account's screens describe: the active one that runs longest, else the
// one that ended last.
export const runningEntitlementOf = (
  entitlements: readonly Entitlement[],
  now: Date,
): Entitlement | undefined => {
  const latestFirst = [...entitlements].sort(
    (a, b) => b.expiresAt.getTime() - a.expiresAt.getTime(),
  )
  return latestFirst.find((entitlement) => isActive(entitlement, now)) ?? latestFirst[0]
}

// What to record when a store vouches for a purchase again, or `stale` to keep what is stored.
// - A payload signed before the stored one is stale: an old transaction replayed, or a
//   notification Apple delivered late, must not move an expiry back or lift a refund.
// - A refund stays a refund: on the same chain, `revokedAt` is lifted only by a payload signed
//   after it (Apple reversing the refund). A payload with no signing date never lifts it.
export const reconciled = (
  stored: Entitlement | undefined,
  incoming: Entitlement,
): Entitlement | 'stale' => {
  if (!stored) return incoming
  if (stored.signedAt && (!incoming.signedAt || incoming.signedAt < stored.signedAt)) return 'stale'
  const sameChain = stored.originalTransactionId === incoming.originalTransactionId
  const refundLifted =
    incoming.signedAt !== undefined &&
    stored.revokedAt !== undefined &&
    incoming.signedAt > stored.revokedAt
  if (sameChain && stored.revokedAt && !incoming.revokedAt && !refundLifted)
    return { ...incoming, revokedAt: stored.revokedAt }
  return incoming
}
