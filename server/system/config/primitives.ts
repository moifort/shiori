import { Environment } from '@apple/app-store-server-library'
import { make } from 'ts-brand'
import { z } from 'zod'
import { UserId } from '~/domain/shared/primitives'
import type { UserId as UserIdType } from '~/domain/shared/types'
import type {
  AdminToken as AdminTokenType,
  ApiToken as ApiTokenType,
  AscIssuerId as AscIssuerIdType,
  AscKeyId as AscKeyIdType,
  AscPrivateKey as AscPrivateKeyType,
  AscVendorNumber as AscVendorNumberType,
  AttachmentsBucket as AttachmentsBucketType,
  AudibleKey as AudibleKeyType,
  GcpBillingTable as GcpBillingTableType,
  GoogleApiKey as GoogleApiKeyType,
  PublicBaseUrl as PublicBaseUrlType,
  SentryDsn as SentryDsnType,
  SentryRelease as SentryReleaseType,
} from '~/system/config/types'

export const ApiToken = (value: unknown) => {
  const v = z.string().min(1).parse(value)
  return make<ApiTokenType>()(v)
}

export const AdminToken = (value: unknown) => {
  const v = z.string().min(1).parse(value)
  return make<AdminTokenType>()(v)
}

export const GoogleApiKey = (value: unknown) => {
  const v = z.string().min(1).parse(value)
  return make<GoogleApiKeyType>()(v)
}

export const SentryDsn = (value: unknown) => {
  // Any non-empty string, like the other config secrets: Sentry.init validates
  // the DSN format itself (warns and disables on a bad one) rather than throwing,
  // so a malformed value can't take down config() — which auth and scan also call.
  const v = z.string().min(1).parse(value)
  return make<SentryDsnType>()(v)
}

export const SentryRelease = (value: unknown) => {
  const v = z.string().min(1).parse(value)
  return make<SentryReleaseType>()(v)
}

// Pins signature verification to one App Store environment. Blank means both
// Production and Sandbox are tried, which is what a shipped app needs (TestFlight
// and review sign in Sandbox); `Xcode` is for the local StoreKit configuration file.
export const AppleEnvironment = (value: unknown) => z.enum(Environment).parse(value) as Environment

// App Store Connect API key pieces, for the sales reports the admin metrics
// read. All-or-nothing at the call site: any of them missing simply means no
// revenue figure, never a crash.
export const AscIssuerId = (value: unknown) => {
  const v = z.string().min(1).parse(value)
  return make<AscIssuerIdType>()(v)
}

export const AscKeyId = (value: unknown) => {
  const v = z.string().min(1).parse(value)
  return make<AscKeyIdType>()(v)
}

export const AscPrivateKey = (value: unknown) => {
  const v = z.string().min(1).parse(value)
  return make<AscPrivateKeyType>()(v)
}

export const AscVendorNumber = (value: unknown) => {
  // The vendor number is all digits, so Nitro's runtime config coerces the
  // NITRO_ASC_VENDOR_NUMBER env var to a number before it ever reaches here.
  // Accept that and stringify it — a bare z.string() would throw at boot, which
  // is exactly what took the function down once the value was set.
  const v = z.coerce.string().min(1).parse(value)
  return make<AscVendorNumberType>()(v)
}

// The BigQuery billing export table, `project.dataset.table` — where actual GCP
// spend lives. Unset means the infra cost simply is not measured.
export const GcpBillingTable = (value: unknown) => {
  const v = z
    .string()
    .regex(/^[^.]+\.[^.]+\.[^.]+$/)
    .parse(value)
  return make<GcpBillingTableType>()(v)
}

// The accounts granted Premium outright (the maker's own, a reviewer's), as one
// comma-separated list of Firebase uids. An override on top of a real entitlement,
// never the source of one.
export const PremiumUserIds = (value: unknown): UserIdType[] =>
  z
    .string()
    .parse(value ?? '')
    .split(',')
    .map((id) => id.trim())
    .filter((id) => id.length > 0)
    .map((id) => UserId(id))

export const AttachmentsBucket = (value: unknown) => {
  const v = z.string().min(1).parse(value)
  return make<AttachmentsBucketType>()(v)
}

// The key the Audible device credentials are sealed with. Checked for length
// here rather than at the first decryption: a truncated key set by hand must
// fail at boot, not the first time a reader connects their account.
export const AudibleKey = (value: unknown) => {
  const v = z
    .string()
    .refine(
      (key) => Buffer.from(key, 'base64').length === 32,
      'audible key must be 32 bytes, base64-encoded',
    )
    .parse(value)
  return make<AudibleKeyType>()(v)
}

export const PublicBaseUrl = (value: unknown) => {
  const v = z.string().url().parse(value)
  return make<PublicBaseUrlType>()(v)
}
