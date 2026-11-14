import { make } from 'ts-brand'
import { z } from 'zod'
import {
  ALERT_KINDS,
  type AlertKind,
  type DeviceToken as DeviceTokenType,
} from '~/domain/notification/types'

// APNs tokens are 32 bytes today, rendered as 64 hex digits; Apple documents
// them as variable length, so the bound is loose on purpose.
const APNS_TOKEN = /^[0-9a-f]{64,200}$/i

// FCM registration tokens are opaque, about 160 characters of letters, digits,
// colons, dashes and underscores; Google gives no fixed length.
const FCM_TOKEN = /^[A-Za-z0-9:_-]{100,4096}$/

export const DeviceToken = (value: unknown) => {
  const v = z
    .string()
    .refine((token) => APNS_TOKEN.test(token) || FCM_TOKEN.test(token), {
      message: 'a device token is an APNs hexadecimal token or an FCM registration token',
    })
    .parse(value)
  return make<DeviceTokenType>()(APNS_TOKEN.test(v) ? v.toLowerCase() : v)
}

export const AlertKindValue = (value: unknown): AlertKind => z.enum(ALERT_KINDS).parse(value)
