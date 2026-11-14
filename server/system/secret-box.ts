import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto'

/** Authenticated encryption for the few secrets Shiori has to keep on behalf of a
 *  reader rather than about them — today, the Amazon device credentials an Audible
 *  connection is made of.
 *
 *  A Firestore export is a plausible way for those to leak, and a leaked refresh
 *  token plus device key is a standing grant on somebody's Amazon account. They
 *  are therefore never written in the clear: the key lives in Secret Manager and
 *  reaches the function as an environment variable, so reading the database is not
 *  enough to use what it holds.
 *
 *  AES-256-GCM rather than CBC: the tag makes a tampered payload fail to open
 *  instead of decrypting into garbage the caller then has to recognize. */

const ALGORITHM = 'aes-256-gcm'
const KEY_BYTES = 32
const IV_BYTES = 12
/** Versioned so a future key rotation can tell the two formats apart rather than
 *  guessing from the field's shape. */
const FORMAT = 'v1'

export const encryptionKeyOf = (base64Key: string): Buffer => {
  const key = Buffer.from(base64Key, 'base64')
  if (key.length !== KEY_BYTES)
    throw new Error(`encryption key must be ${KEY_BYTES} bytes, base64-encoded`)
  return key
}

export const seal = (plaintext: string, key: Buffer): string => {
  const iv = randomBytes(IV_BYTES)
  const cipher = createCipheriv(ALGORITHM, key, iv)
  const sealed = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()])
  return [FORMAT, iv, cipher.getAuthTag(), sealed]
    .map((part) => (typeof part === 'string' ? part : part.toString('base64url')))
    .join('.')
}

export const unseal = (sealed: string, key: Buffer): string => {
  const [format, iv, tag, payload] = sealed.split('.')
  if (format !== FORMAT || !iv || !tag || !payload)
    throw new Error('sealed value is not in the expected format')
  const decipher = createDecipheriv(ALGORITHM, key, Buffer.from(iv, 'base64url'))
  decipher.setAuthTag(Buffer.from(tag, 'base64url'))
  return Buffer.concat([
    decipher.update(Buffer.from(payload, 'base64url')),
    decipher.final(),
  ]).toString('utf8')
}

/** What one integration keeps its device credentials in: sealed with its own
 *  key, so each integration can rotate or lose its key without the other. */
export type CredentialsVault<Credentials, Sealed extends string> = {
  seal: (credentials: Credentials) => Sealed
  open: (sealed: Sealed) => Credentials
  /** The credentials, or nothing when they cannot be opened — sealed with a key
   *  that no longer exists, which no retry will ever open. */
  openIfReadable: (sealed: Sealed) => Credentials | undefined
}

/** A vault for one integration's credentials, stored as JSON.
 *
 *  The key is read per call rather than at import time: `config()` reads
 *  Nitro's runtime config, which is not available while modules are still
 *  loading. `revived` puts back what JSON loses — a date, say. */
export const credentialsVault = <Credentials, Sealed extends string>({
  integration,
  keyName,
  keyOf,
  sealedOf,
  revived = (credentials) => credentials,
}: {
  /** Named in the error a missing key throws: "Audible". */
  integration: string
  /** The environment variable the key comes from: "NITRO_AUDIBLE_KEY". */
  keyName: string
  keyOf: () => string | undefined
  sealedOf: (sealed: string) => Sealed
  revived?: (credentials: Credentials) => Credentials
}): CredentialsVault<Credentials, Sealed> => {
  const key = () => {
    const configured = keyOf()
    if (!configured)
      throw new Error(`${keyName} is not set: ${integration} connections cannot be stored`)
    return encryptionKeyOf(configured)
  }
  const open = (sealed: Sealed): Credentials =>
    revived(JSON.parse(unseal(sealed, key())) as Credentials)
  return {
    seal: (credentials) => sealedOf(seal(JSON.stringify(credentials), key())),
    open,
    openIfReadable: (sealed) => {
      try {
        return open(sealed)
      } catch {
        return undefined
      }
    },
  }
}
