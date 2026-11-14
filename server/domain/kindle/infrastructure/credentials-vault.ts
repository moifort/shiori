import type { KindleCredentials } from 'kindle-api-ts'
import { SealedKindleCredentials } from '~/domain/kindle/primitives'
import type { SealedKindleCredentials as SealedKindleCredentialsValue } from '~/domain/kindle/types'
import { config } from '~/system/config'
import { credentialsVault } from '~/system/secret-box'

/** Turns the Kindle device credentials into something safe to store, and back.
 *
 *  A refresh token plus a device private key is a standing grant on somebody's
 *  Amazon account. It is sealed with a key kept in Secret Manager — its own, not
 *  Audible's — so a Firestore export on its own is inert, and either integration
 *  can rotate or lose its key without touching the other. */
const vault = credentialsVault<KindleCredentials, SealedKindleCredentialsValue>({
  integration: 'Kindle',
  keyName: 'NITRO_KINDLE_KEY',
  keyOf: () => config().kindleKey,
  sealedOf: SealedKindleCredentials,
})

export const sealCredentials = vault.seal
export const openCredentials = vault.open
export const openReadableCredentials = vault.openIfReadable
