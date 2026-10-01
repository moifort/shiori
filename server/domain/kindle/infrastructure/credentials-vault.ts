import type { KindleCredentials } from 'kindle-api-ts'
import { SealedKindleCredentials } from '~/domain/kindle/primitives'
import type { SealedKindleCredentials as SealedKindleCredentialsValue } from '~/domain/kindle/types'
import { config } from '~/system/config'
import { encryptionKeyOf, seal, unseal } from '~/system/secret-box'

/** Turns the Kindle device credentials into something safe to store, and back.
 *
 *  A refresh token plus a device private key is a standing grant on somebody's
 *  Amazon account. It is sealed with a key kept in Secret Manager — its own, not
 *  Audible's — so a Firestore export on its own is inert, and either integration
 *  can rotate or lose its key without touching the other.
 *
 *  The key is read per call: `config()` reads Nitro's runtime config, which is
 *  not available while modules are still loading. */
const key = () => {
  const configured = config().kindleKey
  if (!configured)
    throw new Error('NITRO_KINDLE_KEY is not set: Kindle connections cannot be stored')
  return encryptionKeyOf(configured)
}

export const sealCredentials = (credentials: KindleCredentials): SealedKindleCredentialsValue =>
  SealedKindleCredentials(seal(JSON.stringify(credentials), key()))

export const openCredentials = (sealed: SealedKindleCredentialsValue): KindleCredentials =>
  JSON.parse(unseal(sealed, key())) as KindleCredentials
