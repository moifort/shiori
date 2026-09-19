import type { Brand } from 'ts-brand'

export type ApiToken = Brand<string, 'ApiToken'>
export type AdminToken = Brand<string, 'AdminToken'>
export type GoogleApiKey = Brand<string, 'GoogleApiKey'>
export type SentryDsn = Brand<string, 'SentryDsn'>
/** The deployed revision, as `shiori-node@<git sha>` — ties errors to source maps. */
export type SentryRelease = Brand<string, 'SentryRelease'>
/** App Store Connect API key issuer id (a UUID from the Users and Access page). */
export type AscIssuerId = Brand<string, 'AscIssuerId'>
/** App Store Connect API key id (10-char alphanum, matches the .p8 filename). */
export type AscKeyId = Brand<string, 'AscKeyId'>
/** App Store Connect API private key, the .p8 PEM content. */
export type AscPrivateKey = Brand<string, 'AscPrivateKey'>
/** The vendor number sales reports are filed under (Payments and Financial Reports). */
export type AscVendorNumber = Brand<string, 'AscVendorNumber'>
/** Fully qualified BigQuery billing export table, `project.dataset.table`. */
export type GcpBillingTable = Brand<string, 'GcpBillingTable'>
/** The private bucket holding book cover attachments, e.g. `shiori-polyforms-attachments`. */
export type AttachmentsBucket = Brand<string, 'AttachmentsBucket'>
/** The 256-bit key, base64-encoded, the Audible device credentials are sealed
 *  with before they reach Firestore. */
export type AudibleKey = Brand<string, 'AudibleKey'>
/** Development only: the origin this server is reachable at, used to address the
 *  local object store from the simulator. */
export type PublicBaseUrl = Brand<string, 'PublicBaseUrl'>
