import { describe, expect, test } from 'bun:test'
import { randomBytes } from 'node:crypto'
import { credentialsVault, encryptionKeyOf, seal, unseal } from '~/system/secret-box'

const key = randomBytes(32)

describe('sealing a secret', () => {
  test('reads back exactly what was sealed', () => {
    const secret = JSON.stringify({ refreshToken: 'Atnr|…', serial: 'ABC123' })

    expect(unseal(seal(secret, key), key)).toBe(secret)
  })

  // Same plaintext twice must not produce the same ciphertext, or a Firestore
  // export would show at a glance which accounts share a value.
  test('seals the same value differently every time', () => {
    expect(seal('same', key)).not.toBe(seal('same', key))
  })

  test('refuses to open a payload that was tampered with', () => {
    const sealed = seal('same', key)
    const [format, iv, tag, payload] = sealed.split('.')

    expect(() => unseal(`${format}.${iv}.${tag}.${payload}00`, key)).toThrow()
  })

  test('refuses to open with another key', () => {
    expect(() => unseal(seal('same', key), randomBytes(32))).toThrow()
  })

  test('refuses a value that is not in the sealed format', () => {
    expect(() => unseal('plain text', key)).toThrow('sealed value is not in the expected format')
  })
})

describe('reading the key', () => {
  test('accepts a base64 256-bit key', () => {
    expect(encryptionKeyOf(randomBytes(32).toString('base64'))).toHaveLength(32)
  })

  test('refuses a key of the wrong length, rather than padding it', () => {
    expect(() => encryptionKeyOf(randomBytes(16).toString('base64'))).toThrow(
      'encryption key must be 32 bytes',
    )
  })
})

describe('credentialsVault', () => {
  const keyA = randomBytes(32).toString('base64')
  const keyB = randomBytes(32).toString('base64')
  const vaultUnder = (key: string | undefined) =>
    credentialsVault<{ token: string; expiresAt: Date }, string>({
      integration: 'Test',
      keyName: 'NITRO_TEST_KEY',
      keyOf: () => key,
      sealedOf: (sealed) => sealed,
      revived: (credentials) => ({ ...credentials, expiresAt: new Date(credentials.expiresAt) }),
    })

  test('opens what it sealed, with what JSON loses put back', () => {
    const vault = vaultUnder(keyA)
    const credentials = { token: 'refresh', expiresAt: new Date('2026-11-14T10:00:00.000Z') }
    expect(vault.open(vault.seal(credentials))).toEqual(credentials)
  })

  // Each integration keeps its own key: one sealed under another opens to nothing.
  test('a value sealed under another key is unreadable, not an error', () => {
    const sealed = vaultUnder(keyA).seal({ token: 'refresh', expiresAt: new Date() })
    expect(vaultUnder(keyB).openIfReadable(sealed)).toBeUndefined()
    expect(() => vaultUnder(keyB).open(sealed)).toThrow()
  })

  test('refuses to seal without its key, naming it', () => {
    expect(() => vaultUnder(undefined).seal({ token: 'refresh', expiresAt: new Date() })).toThrow(
      'NITRO_TEST_KEY is not set: Test connections cannot be stored',
    )
  })
})
