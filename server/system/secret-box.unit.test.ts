import { describe, expect, test } from 'bun:test'
import { randomBytes } from 'node:crypto'
import { encryptionKeyOf, seal, unseal } from '~/system/secret-box'

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
