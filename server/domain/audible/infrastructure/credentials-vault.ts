import type { AudibleCredentials } from 'audible-api-ts'
import { SealedCredentials } from '~/domain/audible/primitives'
import type { SealedCredentials as SealedCredentialsValue } from '~/domain/audible/types'
import { config } from '~/system/config'
import { credentialsVault } from '~/system/secret-box'

/** Turns the Amazon device credentials into something safe to store, and back.
 *
 *  A refresh token plus a device private key is a standing grant on somebody's
 *  Amazon account — the one secret Shiori holds that is dangerous away from
 *  Shiori. It is therefore sealed with a key kept in Secret Manager, so a
 *  Firestore export on its own is inert. */
const vault = credentialsVault<AudibleCredentials, SealedCredentialsValue>({
  integration: 'Audible',
  keyName: 'NITRO_AUDIBLE_KEY',
  keyOf: () => config().audibleKey,
  sealedOf: SealedCredentials,
  // JSON has no date, and the client compares `expiresAt` to decide whether to
  // refresh the access token. A string there silently never looks expired.
  revived: (credentials) => ({ ...credentials, expiresAt: new Date(credentials.expiresAt) }),
})

export const sealCredentials = vault.seal
export const openCredentials = vault.open
export const openReadableCredentials = vault.openIfReadable
