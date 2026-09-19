import type { AudibleCredentials } from 'audible-api-ts'
import { SealedCredentials } from '~/domain/audible/primitives'
import type { SealedCredentials as SealedCredentialsValue } from '~/domain/audible/types'
import { config } from '~/system/config'
import { encryptionKeyOf, seal, unseal } from '~/system/secret-box'

/** Turns the Amazon device credentials into something safe to store, and back.
 *
 *  A refresh token plus a device private key is a standing grant on somebody's
 *  Amazon account — the one secret Shiori holds that is dangerous away from
 *  Shiori. It is therefore sealed with a key kept in Secret Manager, so a
 *  Firestore export on its own is inert.
 *
 *  The key is read per call rather than at import time: `config()` reads Nitro's
 *  runtime config, which is not available while modules are still loading. */
const key = () => {
  const configured = config().audibleKey
  if (!configured)
    throw new Error('NITRO_AUDIBLE_KEY is not set: Audible connections cannot be stored')
  return encryptionKeyOf(configured)
}

export const sealCredentials = (credentials: AudibleCredentials): SealedCredentialsValue =>
  SealedCredentials(seal(JSON.stringify(credentials), key()))

export const openCredentials = (sealed: SealedCredentialsValue): AudibleCredentials => {
  const credentials = JSON.parse(unseal(sealed, key())) as AudibleCredentials
  // JSON has no date, and the client compares `expiresAt` to decide whether to
  // refresh the access token. A string there silently never looks expired.
  return { ...credentials, expiresAt: new Date(credentials.expiresAt) }
}
