import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { randomBytes } from 'node:crypto'
import { graphql } from 'graphql'
import type { KindleTitle } from 'kindle-api-ts'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
const kindleKey = randomBytes(32).toString('base64')
mock.module('~/system/config', () => ({ config: () => ({ kindleKey }) }))
mock.module('~/system/object-store', () => ({
  objectStore: () => ({ downloadUrl: async () => 'https://fake.store/cover' }),
}))

let titles: KindleTitle[] = []
let libraryFails: Error | undefined

mock.module('~/domain/kindle/infrastructure/kindle-api', () => ({
  login: async (marketplace: string) => ({
    loginUrl: `https://www.amazon.${marketplace}/ap/signin?openid.oa2.code_challenge=xyz`,
    session: {
      codeVerifier: 'verifier-1',
      serial: 'SERIAL1',
      locale: marketplace,
      createdAt: new Date(),
    },
    cookies: [{ name: 'frc', value: 'planted', domain: `.amazon.${marketplace}` }],
  }),
  register: async () => ({
    refreshToken: 'Atnr|the-refresh-token',
    adpToken: '{enc:token}',
    devicePrivateKey: 'key',
    serial: 'SERIAL1',
    locale: 'fr',
  }),
  library: async () => {
    if (libraryFails) throw libraryFails
    return titles
  },
  landingUrlFor: (marketplace: string) => `https://www.amazon.${marketplace}/ap/maplanding`,
}))

const { schema } = await import('~/domain/shared/graphql/schema')

const userId = 'reader-1' as UserId

const aTitle = (overrides: Partial<KindleTitle> = {}): KindleTitle => ({
  asin: 'B0TESTAAA1',
  title: 'Powerless (Tome 3) - Fearless',
  authors: ['Lauren Roberts'],
  coverUrl: 'https://m.media-amazon.com/images/I/91cover.jpg',
  readStatus: 'READ',
  originType: 'Purchase',
  category: 'KindleEBook',
  acquiredAt: new Date('2026-09-14T10:00:00.000Z'),
  ...overrides,
})

beforeEach(() => {
  resetFakeFirestore()
  titles = []
  libraryFails = undefined
})

const execute = (source: string) => graphql({ schema, source, contextValue: { event: {}, userId } })
const codeOf = (result: Awaited<ReturnType<typeof execute>>) => result.errors?.[0]?.extensions?.code

const connect = async () => {
  const started = await execute('mutation { startKindleLogin(marketplace: FR) { url } }')
  expect(started.errors).toBeUndefined()
  const linked = await execute(
    'mutation { completeKindleLogin(authorizationCode: "the-code") { marketplace } }',
  )
  expect(linked.errors).toBeUndefined()
}

describe('connecting a Kindle library through the API', () => {
  test('hands the app everything the web view needs', async () => {
    const result = await execute(
      'mutation { startKindleLogin(marketplace: FR) { url redirectUrl cookies { name domain } } }',
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.startKindleLogin).toEqual({
      url: 'https://www.amazon.fr/ap/signin?openid.oa2.code_challenge=xyz',
      redirectUrl: 'https://www.amazon.fr/ap/maplanding',
      cookies: [{ name: 'frc', domain: '.amazon.fr' }],
    })
  })

  test('reads back as connected, syncing nightly, once the code has been exchanged', async () => {
    await connect()

    const result = await execute(
      'query { kindleAccount { marketplace autoSync lastImportedAt lastSyncFailedAt } }',
    )
    expect(result.errors).toBeUndefined()
    expect(result.data?.kindleAccount).toEqual({
      marketplace: 'FR',
      autoSync: true,
      lastImportedAt: null,
      lastSyncFailedAt: null,
    })
  })

  // Two independent connections: linking Kindle says nothing about Audible.
  test('leaves the Audible connection as it was', async () => {
    await connect()

    const result = await execute('query { audibleAccount { marketplace } }')
    expect(result.data?.audibleAccount).toBeNull()
  })

  test('reads back as nothing for a reader who never connected', async () => {
    const result = await execute('query { kindleAccount { marketplace } }')

    expect(result.errors).toBeUndefined()
    expect(result.data?.kindleAccount).toBeNull()
  })

  test('refuses a code when no sign-in is in progress, and an empty one', async () => {
    const none = await execute(
      'mutation { completeKindleLogin(authorizationCode: "the-code") { marketplace } }',
    )
    const empty = await execute(
      'mutation { completeKindleLogin(authorizationCode: "  ") { marketplace } }',
    )

    expect(codeOf(none)).toBe('KINDLE_NO_PENDING_LOGIN')
    expect(codeOf(empty)).toBe('BAD_USER_INPUT')
  })

  test('forgets the connection on request, and says when there was none', async () => {
    await connect()

    expect((await execute('mutation { disconnectKindle }')).data?.disconnectKindle).toBe(true)
    expect((await execute('mutation { disconnectKindle }')).data?.disconnectKindle).toBe(false)
  })
})

describe('listing and importing through the API', () => {
  test('proposes the library, the saga read out of the title', async () => {
    await connect()
    titles = [aTitle(), aTitle({ asin: 'B0TESTDICT', originType: 'KindleDictionary' })]

    const result = await execute(
      'query { kindleAccount { library { asin title authors coverUrl seriesName volume status alreadyInLibrary } } }',
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.kindleAccount).toEqual({
      library: [
        {
          asin: 'B0TESTAAA1',
          title: 'Fearless',
          authors: ['Lauren Roberts'],
          coverUrl: 'https://m.media-amazon.com/images/I/91cover.jpg',
          seriesName: 'Powerless',
          volume: 3,
          status: 'READ',
          alreadyInLibrary: false,
        },
      ],
    })
  })

  test('catalogues the ticked titles as ebooks, and creates no duplicate', async () => {
    await connect()
    titles = [aTitle()]

    const first = await execute(
      'mutation { importKindleLibrary(asins: ["B0TESTAAA1"]) { title format status coverUrl } }',
    )
    const second = await execute('mutation { importKindleLibrary(asins: ["B0TESTAAA1"]) { id } }')

    expect(first.errors).toBeUndefined()
    expect(first.data?.importKindleLibrary).toEqual([
      {
        title: 'Fearless',
        format: 'EBOOK',
        status: 'READ',
        coverUrl: 'https://m.media-amazon.com/images/I/91cover.jpg',
      },
    ])
    expect(second.data?.importKindleLibrary).toEqual([])
  })

  test('refuses an identifier that is not an ASIN, as bad input', async () => {
    await connect()

    const result = await execute('mutation { importKindleLibrary(asins: ["nope"]) { id } }')
    expect(codeOf(result)).toBe('BAD_USER_INPUT')
  })

  test('refuses when no library is connected', async () => {
    const listed = await execute('query { kindleLibrary { asin } }')
    const imported = await execute('mutation { importKindleLibrary(asins: ["B0TESTAAA1"]) { id } }')

    expect(codeOf(listed)).toBe('KINDLE_NOT_CONNECTED')
    expect(codeOf(imported)).toBe('KINDLE_NOT_CONNECTED')
  })

  test('reports one error when Amazon refuses the call', async () => {
    await connect()
    libraryFails = new Error('Cookie exchange failed: 401 Unauthorized')

    const result = await execute('query { kindleLibrary { asin } }')
    expect(codeOf(result)).toBe('KINDLE_UNAVAILABLE')
  })
})

describe('the nightly sync through the API', () => {
  test('turning it off is what the account reads back', async () => {
    await connect()

    const result = await execute('mutation { setKindleAutoSync(enabled: false) { autoSync } }')
    expect(result.data?.setKindleAutoSync).toEqual({ autoSync: false })
  })

  test('refuses to keep a setting no library backs', async () => {
    const result = await execute('mutation { setKindleAutoSync(enabled: false) { autoSync } }')
    expect(codeOf(result)).toBe('KINDLE_NOT_CONNECTED')
  })

  test('a pass asked for now says what it brought back, even with the switch off', async () => {
    await connect()
    await execute('mutation { setKindleAutoSync(enabled: false) { autoSync } }')
    titles = [aTitle(), aTitle({ asin: 'B0TESTBBB2', title: 'Autre' })]

    const result = await execute(
      'mutation { syncKindleNow { imported updated account { lastImportedAt } } }',
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.syncKindleNow).toMatchObject({
      imported: 2,
      updated: 0,
      account: { lastImportedAt: expect.any(String) },
    })
  })
})
