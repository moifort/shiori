import { make } from 'ts-brand'
import { z } from 'zod'
import { ALERT_KINDS, type AlertKind, type DeviceToken as DeviceTokenType } from './types'

// APNs tokens are 32 bytes today, rendered as 64 hex digits; Apple documents
// them as variable length, so the bound is loose on purpose.
export const DeviceToken = (value: unknown) => {
  const v = z
    .string()
    .regex(/^[0-9a-f]{64,200}$/i, 'a device token is hexadecimal')
    .parse(value)
  return make<DeviceTokenType>()(v.toLowerCase())
}

export const AlertKindValue = (value: unknown): AlertKind => z.enum(ALERT_KINDS).parse(value)
