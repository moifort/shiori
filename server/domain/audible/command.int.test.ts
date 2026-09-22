import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { randomBytes } from 'node:crypto'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore, startFakeRequest } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
// One key for the whole file: config() is read on every seal and every open, and
// a fresh key per call would make a sealed value unreadable a line later.
const audibleKey = randomBytes(32).toString('base64')
mock.module('~/system/config', () => ({ config: () => ({ audibleKey }) }))

/** Stands in for Amazon. Nobody registers a device in a test — what is asserted
 *  is what the domain does with the answer, and above all what it writes down. */
let registrations: string[] = []
let registerFails: Error | undefined

mock.module('~/domain/audible/infrastructure/audible-api', () => ({
  login: async (marketplace: string) => ({
    loginUrl: `https://www.amazon.${marketplace}/ap/signin?openid.oa2.code_challenge=xyz`,
    session: { codeVerifier: 'verifier-1', serial: 'SERIAL1', marketplace, createdAt: NOW },
    cookies: [{ name: 'frc', value: 'planted', domain: `.amazon.${marketplace}` }],
  }),
  register: async (authorizationCode: string) => {
    registrations.push(authorizationCode)
    if (registerFails) throw registerFails
    return {
      accessToken: 'access-1',
      refreshToken: 'Atnr|the-refresh-token',
      adpToken: '{enc:the-adp-token}',
      devicePrivateKey: '-----BEGIN RSA PRIVATE KEY-----',
      serial: 'SERIAL1',
      locale: 'fr',
      expiresAt: new Date('2026-09-19T11:00:00.000Z'),
    }
  },
  library: async () => ({ items: [], credentials: {} }),
  landingUrlOf: (marketplace: string) => `https://www.amazon.${marketplace}/ap/maplanding`,
}))

const { AudibleCommand } = await import('~/domain/audible/command')
const { AudibleQuery } = await import('~/domain/audible/query')

const reader = 'reader-1' as UserId
const NOW = new Date('2026-09-19T10:00:00.000Z')

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
  registrations = []
  registerFails = undefined
})

const connect = async (marketplace: 'fr' | 'com' = 'fr') => {
  await AudibleCommand.startLogin(reader, marketplace, NOW)
  return AudibleCommand.completeLogin(reader, 'the-code', NOW)
}

describe('opening an Audible sign-in', () => {
  test('hands the app the page, the cookies and the redirect to watch for', async () => {
    const login = await AudibleCommand.startLogin(reader, 'fr', NOW)

    expect(login.url).toContain('https://www.amazon.fr/ap/signin')
    expect(login.cookies).toEqual([{ name: 'frc', value: 'planted', domain: '.amazon.fr' }])
    expect(login.redirectUrl).toBe('https://www.amazon.fr/ap/maplanding')
  })

  // PKCE only protects the exchange as long as the verifier stays put. It is
  // written down here and never handed to the client.
  test('keeps the code verifier on the server', async () => {
    const login = await AudibleCommand.startLogin(reader, 'fr', NOW)

    expect(JSON.stringify(login)).not.toContain('verifier-1')
    expect(fake.data('audible-connections', reader)).toMatchObject({
      pending: { codeVerifier: 'verifier-1', serial: 'SERIAL1', marketplace: 'fr' },
    })
  })

  // A reader who opens the sheet and changes their mind must not come back to a
  // disconnected account.
  test('leaves a working connection alone until the new sign-in completes', async () => {
    await connect()

    await AudibleCommand.startLogin(reader, 'com', NOW)

    expect(await AudibleQuery.accountOf(reader)).toMatchObject({ marketplace: 'fr' })
  })
})

describe('finishing the sign-in', () => {
  test('links the account on the marketplace the sign-in was opened for', async () => {
    const account = await connect('com')

    expect(account).toMatchObject({ marketplace: 'com', connectedAt: NOW })
    expect(registrations).toEqual(['the-code'])
  })

  // A refresh token plus a device key is a standing grant on somebody's Amazon
  // account. A Firestore export must not be enough to use it.
  test('writes no credential in the clear', async () => {
    await connect()

    const stored = JSON.stringify(fake.data('audible-connections', reader))
    expect(stored).not.toContain('Atnr|the-refresh-token')
    expect(stored).not.toContain('BEGIN RSA PRIVATE KEY')
    expect(stored).not.toContain('the-adp-token')
  })

  // A code verifier is good for one exchange, so it must not survive it.
  test('drops the spent sign-in', async () => {
    await connect()

    expect(Object.hasOwn(fake.data('audible-connections', reader) as object, 'pending')).toBe(false)
  })

  test('refuses a code when no sign-in was started', async () => {
    expect(await AudibleCommand.completeLogin(reader, 'the-code', NOW)).toBe('no-pending-login')
  })

  test('refuses a sign-in the reader walked away from, and clears it', async () => {
    await AudibleCommand.startLogin(reader, 'fr', NOW)
    const anHourLater = new Date(NOW.getTime() + 60 * 60 * 1000)

    expect(await AudibleCommand.completeLogin(reader, 'the-code', anHourLater)).toBe(
      'login-expired',
    )
    expect(registrations).toEqual([])
    expect(await AudibleCommand.completeLogin(reader, 'the-code', anHourLater)).toBe(
      'no-pending-login',
    )
  })

  test('leaves the reader unconnected when Amazon refuses the registration', async () => {
    await AudibleCommand.startLogin(reader, 'fr', NOW)
    registerFails = new Error('Device registration failed: 400 Bad Request')

    await expect(AudibleCommand.completeLogin(reader, 'the-code', NOW)).rejects.toThrow(
      'Device registration failed',
    )
    expect(await AudibleQuery.accountOf(reader)).toBeUndefined()
  })
})

describe('reading the connection back', () => {
  test('reads as unconnected while only a sign-in is in flight', async () => {
    await AudibleCommand.startLogin(reader, 'fr', NOW)

    expect(await AudibleQuery.accountOf(reader)).toBeUndefined()
  })

  // The settings screen reads it, and an import reads it again to decrypt the
  // credentials. One document read between them.
  test('costs one read however many times the request asks for it', async () => {
    await connect()
    startFakeRequest()
    const before = fake.docReads

    await AudibleQuery.accountOf(reader)
    await AudibleQuery.accountOf(reader)

    expect(fake.docReads - before).toBe(1)
    expect(fake.queryReads).toBe(0)
  })
})

describe('disconnecting', () => {
  test('forgets the credentials', async () => {
    await connect()

    expect(await AudibleCommand.disconnect(reader)).toBe('disconnected')
    expect(fake.data('audible-connections', reader)).toBeNull()
  })

  test('says so when there was nothing to disconnect', async () => {
    expect(await AudibleCommand.disconnect(reader)).toBe('not-connected')
  })

  test('takes the connection with the account on deletion', async () => {
    await connect()

    await AudibleCommand.deleteForUser(reader)

    expect(fake.data('audible-connections', reader)).toBeNull()
  })
})
