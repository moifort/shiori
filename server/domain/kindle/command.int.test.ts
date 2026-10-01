import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { randomBytes } from 'node:crypto'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore, startFakeRequest } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
// One key for the whole file: config() is read on every seal and every open.
const kindleKey = randomBytes(32).toString('base64')
mock.module('~/system/config', () => ({ config: () => ({ kindleKey }) }))

/** Stands in for Amazon: nobody registers a device in a test. What is asserted
 *  is what the domain writes down. */
let registrations: string[] = []
let registerFails: Error | undefined

mock.module('~/domain/kindle/infrastructure/kindle-api', () => ({
  login: async (marketplace: string) => ({
    loginUrl: `https://www.amazon.${marketplace}/ap/signin?openid.oa2.code_challenge=xyz`,
    session: { codeVerifier: 'verifier-1', serial: 'SERIAL1', locale: marketplace, createdAt: NOW },
    cookies: [{ name: 'frc', value: 'planted', domain: `.amazon.${marketplace}` }],
  }),
  register: async (authorizationCode: string) => {
    registrations.push(authorizationCode)
    if (registerFails) throw registerFails
    return {
      refreshToken: 'Atnr|the-refresh-token',
      adpToken: '{enc:the-adp-token}',
      devicePrivateKey: '-----BEGIN RSA PRIVATE KEY-----',
      serial: 'SERIAL1',
      locale: 'fr',
    }
  },
  library: async () => [],
  landingUrlFor: (marketplace: string) => `https://www.amazon.${marketplace}/ap/maplanding`,
}))

const { KindleCommand } = await import('~/domain/kindle/command')
const { KindleQuery } = await import('~/domain/kindle/query')
const { openCredentials } = await import('~/domain/kindle/infrastructure/credentials-vault')
const { KindleAsin } = await import('~/domain/kindle/primitives')

const reader = 'reader-1' as UserId
const NOW = new Date('2026-10-01T10:00:00.000Z')

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
  registrations = []
  registerFails = undefined
})

const connect = async () => {
  await KindleCommand.startLogin(reader, 'fr', NOW)
  return KindleCommand.completeLogin(reader, 'the-code', NOW)
}

describe('opening a Kindle sign-in', () => {
  test('hands the app the page, the cookies and the redirect to watch for', async () => {
    const login = await KindleCommand.startLogin(reader, 'fr', NOW)

    expect(login).toEqual({
      url: 'https://www.amazon.fr/ap/signin?openid.oa2.code_challenge=xyz',
      cookies: [{ name: 'frc', value: 'planted', domain: '.amazon.fr' }],
      redirectUrl: 'https://www.amazon.fr/ap/maplanding',
    })
  })

  // The PKCE secret stays on the server: the app never holds a piece of it.
  test('keeps the code verifier on the server, in the reader’s own document', async () => {
    await KindleCommand.startLogin(reader, 'fr', NOW)

    expect(fake.data('kindle-connections', reader)).toMatchObject({
      userId: reader,
      pending: { marketplace: 'fr', codeVerifier: 'verifier-1', serial: 'SERIAL1' },
    })
  })

  test('leaves an existing connection working until the new one completes', async () => {
    await connect()
    startFakeRequest()
    await KindleCommand.startLogin(reader, 'com', NOW)

    expect((await KindleQuery.accountOf(reader))?.marketplace).toBe('fr')
  })
})

describe('completing a Kindle sign-in', () => {
  test('links the library, its credentials sealed, the sign-in spent', async () => {
    const account = await connect()

    expect(account).toMatchObject({ marketplace: 'fr', connectedAt: NOW, autoSync: true })
    const stored = fake.data('kindle-connections', reader) as { account: { credentials: string } }
    expect(stored).not.toHaveProperty('pending')
    expect(stored.account.credentials).not.toContain('Atnr')
    expect(openCredentials(stored.account.credentials as never).refreshToken).toBe(
      'Atnr|the-refresh-token',
    )
  })

  test('refuses a code when no sign-in is in progress', async () => {
    expect(await KindleCommand.completeLogin(reader, 'the-code', NOW)).toBe('no-pending-login')
    expect(registrations).toEqual([])
  })

  test('refuses a sign-in started more than half an hour ago, and drops it', async () => {
    await KindleCommand.startLogin(reader, 'fr', NOW)
    const later = new Date(NOW.getTime() + 31 * 60 * 1000)

    expect(await KindleCommand.completeLogin(reader, 'the-code', later)).toBe('login-expired')
    expect(registrations).toEqual([])
    expect(fake.data('kindle-connections', reader)).not.toHaveProperty('pending')
  })

  test('lets Amazon’s refusal through, the sign-in left in place', async () => {
    await KindleCommand.startLogin(reader, 'fr', NOW)
    registerFails = new Error('Device registration failed: 403 Forbidden')

    await expect(KindleCommand.completeLogin(reader, 'the-code', NOW)).rejects.toThrow('403')
    expect(await KindleQuery.accountOf(reader)).toBeUndefined()
  })
})

describe('recording passes', () => {
  test('keeps when, and which titles Amazon reported read', async () => {
    await connect()
    await KindleCommand.recordPass(reader, [KindleAsin('B0TESTAAA1')], NOW)

    const account = await KindleQuery.accountOf(reader)
    expect(account?.lastImportedAt).toEqual(NOW)
    expect(account?.readAsins).toEqual([KindleAsin('B0TESTAAA1')])
  })

  test('leaves the read set alone when given none', async () => {
    await connect()
    await KindleCommand.recordPass(reader, [KindleAsin('B0TESTAAA1')], NOW)
    await KindleCommand.recordPass(reader, undefined, NOW)

    expect((await KindleQuery.accountOf(reader))?.readAsins).toEqual([KindleAsin('B0TESTAAA1')])
  })

  test('clears the failure a night before recorded', async () => {
    await connect()
    await KindleCommand.recordFailure(reader, NOW)
    expect((await KindleQuery.accountOf(reader))?.lastSyncFailedAt).toEqual(NOW)

    await KindleCommand.recordPass(reader, [], NOW)
    expect(fake.data('kindle-connections', reader)).not.toHaveProperty('account.lastSyncFailedAt')
  })
})

describe('governing and dropping the connection', () => {
  test('turns the nightly sync off', async () => {
    await connect()

    expect(await KindleCommand.setAutoSync(reader, false)).toMatchObject({ autoSync: false })
    expect((await KindleQuery.accountOf(reader))?.autoSync).toBe(false)
  })

  test('refuses a setting no library backs', async () => {
    expect(await KindleCommand.setAutoSync(reader, false)).toBe('not-connected')
    expect(fake.data('kindle-connections', reader)).toBeNull()
  })

  test('forgets the connection, and says when there was none', async () => {
    await connect()

    expect(await KindleCommand.disconnect(reader)).toBe('disconnected')
    expect(await KindleCommand.disconnect(reader)).toBe('not-connected')
    expect(fake.data('kindle-connections', reader)).toBeNull()
  })

  // A half-started sign-in is not a library.
  test('reads a sign-in in flight as not connected', async () => {
    await KindleCommand.startLogin(reader, 'fr', NOW)

    expect(await KindleQuery.accountOf(reader)).toBeUndefined()
  })
})

describe('the nightly queue', () => {
  test('the least recently synced first, without readers who turned it off', async () => {
    const other = 'reader-2' as UserId
    const off = 'reader-3' as UserId
    for (const who of [reader, other, off]) {
      await KindleCommand.startLogin(who, 'fr', NOW)
      await KindleCommand.completeLogin(who, 'the-code', NOW)
    }
    await KindleCommand.recordPass(reader, [], new Date('2026-10-01T04:30:00.000Z'))
    await KindleCommand.setAutoSync(off, false)

    expect(await KindleQuery.readersToSync()).toEqual([other, reader])
  })
})
