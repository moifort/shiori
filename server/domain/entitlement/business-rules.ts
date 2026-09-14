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

// The plan an account is on. Absent entitlement, expired entitlement, revoked
// entitlement: all three are `free`. There is no other way to be Premium.
export const planOf = (entitlement: Entitlement | undefined, now: Date): Plan =>
  entitlement && isActive(entitlement, now) ? 'premium' : 'free'
