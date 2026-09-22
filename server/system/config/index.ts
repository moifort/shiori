import {
  AdminToken,
  ApiToken,
  ApnsKeyId,
  ApnsPrivateKey,
  ApnsTeamId,
  AppleEnvironment,
  AscIssuerId,
  AscKeyId,
  AscPrivateKey,
  AscVendorNumber,
  AttachmentsBucket,
  AudibleKey,
  GcpBillingTable,
  GoogleApiKey,
  PremiumUserIds,
  PublicBaseUrl,
  SentryDsn,
  SentryRelease,
} from '~/system/config/primitives'

export const config = () => {
  const runtimeConfig = useRuntimeConfig()
  return {
    apiToken: runtimeConfig.apiToken ? ApiToken(runtimeConfig.apiToken) : undefined,
    adminToken: runtimeConfig.adminToken ? AdminToken(runtimeConfig.adminToken) : undefined,
    googleApiKey: GoogleApiKey(runtimeConfig.googleApiKey),
    sentryDsn: runtimeConfig.sentryDsn ? SentryDsn(runtimeConfig.sentryDsn) : undefined,
    sentryRelease: runtimeConfig.sentryRelease
      ? SentryRelease(runtimeConfig.sentryRelease)
      : undefined,
    devUserId: runtimeConfig.devUserId || undefined,
    scanStub: Boolean(runtimeConfig.scanStub),
    appleEnvironment: runtimeConfig.appleEnvironment
      ? AppleEnvironment(runtimeConfig.appleEnvironment)
      : undefined,
    premiumUserIds: PremiumUserIds(runtimeConfig.premiumUserIds),
    ascIssuerId: runtimeConfig.ascIssuerId ? AscIssuerId(runtimeConfig.ascIssuerId) : undefined,
    ascKeyId: runtimeConfig.ascKeyId ? AscKeyId(runtimeConfig.ascKeyId) : undefined,
    ascPrivateKey: runtimeConfig.ascPrivateKey
      ? AscPrivateKey(runtimeConfig.ascPrivateKey)
      : undefined,
    ascVendorNumber: runtimeConfig.ascVendorNumber
      ? AscVendorNumber(runtimeConfig.ascVendorNumber)
      : undefined,
    gcpBillingTable: runtimeConfig.gcpBillingTable
      ? GcpBillingTable(runtimeConfig.gcpBillingTable)
      : undefined,
    attachmentsBucket: runtimeConfig.attachmentsBucket
      ? AttachmentsBucket(runtimeConfig.attachmentsBucket)
      : undefined,
    audibleKey: runtimeConfig.audibleKey ? AudibleKey(runtimeConfig.audibleKey) : undefined,
    apnsKeyId: runtimeConfig.apnsKeyId ? ApnsKeyId(runtimeConfig.apnsKeyId) : undefined,
    apnsPrivateKey: runtimeConfig.apnsPrivateKey
      ? ApnsPrivateKey(runtimeConfig.apnsPrivateKey)
      : undefined,
    apnsTeamId: runtimeConfig.apnsTeamId ? ApnsTeamId(runtimeConfig.apnsTeamId) : undefined,
    publicBaseUrl: PublicBaseUrl(runtimeConfig.publicBaseUrl),
  }
}
