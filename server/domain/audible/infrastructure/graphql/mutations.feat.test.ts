import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { randomBytes } from 'node:crypto'
import type { AudibleItem } from 'audible-api-ts'
import { graphql } from 'graphql'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
// One key for the whole file: a fresh key per config() call would make a sealed
// value unreadable a line later.
const audibleKey = randomBytes(32).toString('base64')
mock.module('~/system/config', () => ({ config: () => ({ audibleKey }) }))
mock.module('~/system/object-store', () => ({
  objectStore: () => ({ downloadUrl: async () => 'https://fake.store/cover' }),
}))

let items: AudibleItem[] = []
let libraryFails: Error | undefined

mock.module('~/domain/audible/infrastructure/audible-api', () => ({
  login: async (marketplace: string) => ({
    loginUrl: `https://www.amazon.${marketplace}/ap/signin?openid.oa2.code_challenge=xyz`,
    session: { codeVerifier: 'verifier-1', serial: 'SERIAL1', marketplace, createdAt: new Date() },
    cookies: [{ name: 'frc', value: 'planted', domain: `.amazon.${marketplace}` }],
  }),
  register: async () => ({
    accessToken: 'access-1',
    refreshToken: 'Atnr|the-refresh-token',
    adpToken: '{enc:token}',
    devicePrivateKey: 'key',
    serial: 'SERIAL1',
    locale: 'fr',
    expiresAt: new Date('2026-09-19T11:00:00.000Z'),
  }),
  library: async (credentials: unknown) => {
    if (libraryFails) throw libraryFails
    return { items, credentials }
  },
  // Nobody has stopped anywhere: the statuses under test come off the library.
  lastPositions: async (credentials: unknown) => ({ positions: [], credentials }),
  landingUrlOf: (marketplace: string) => `https://www.amazon.${marketplace}/ap/maplanding`,
}))

const { schema } = await import('~/domain/shared/graphql/schema')

const userId = 'reader-1' as UserId

const anItem = (overrides: Partial<AudibleItem> = {}): AudibleItem =>
  ({
    asin: 'B002V1OF70',
    title: 'Le Nom du vent',
    authors: ['Patrick Rothfuss'],
    narrators: ['Bernard Gabay'],
    durationMinutes: 1770,
    categories: [],
    keywords: [],
    relationships: [],
    isAdultProduct: false,
    productImages: { '900': 'https://m.media-amazon.com/images/I/900.jpg' },
    socialMediaImages: {},
    ...overrides,
  }) as AudibleItem

beforeEach(() => {
  resetFakeFirestore()
  items = []
  libraryFails = undefined
})

const execute = (source: string) => graphql({ schema, source, contextValue: { event: {}, userId } })

const codeOf = (result: Awaited<ReturnType<typeof execute>>) => result.errors?.[0]?.extensions?.code

const connect = async () => {
  const started = await execute('mutation { startAudibleLogin(marketplace: FR) { url } }')
  expect(started.errors).toBeUndefined()
  const linked = await execute(
    'mutation { completeAudibleLogin(authorizationCode: "the-code") { marketplace } }',
  )
  expect(linked.errors).toBeUndefined()
  return linked
}

describe('connecting an Audible account through the API', () => {
  test('hands the app everything the web view needs', async () => {
    const result = await execute(
      'mutation { startAudibleLogin(marketplace: FR) { url redirectUrl cookies { name domain } } }',
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.startAudibleLogin).toEqual({
      url: 'https://www.amazon.fr/ap/signin?openid.oa2.code_challenge=xyz',
      redirectUrl: 'https://www.amazon.fr/ap/maplanding',
      cookies: [{ name: 'frc', domain: '.amazon.fr' }],
    })
  })

  test('reads back as connected once the code has been exchanged', async () => {
    await connect()

    const result = await execute('query { audibleAccount { marketplace lastImportedAt } }')

    expect(result.errors).toBeUndefined()
    expect(result.data?.audibleAccount).toEqual({ marketplace: 'FR', lastImportedAt: null })
  })

  test('reads back as nothing for a reader who never connected', async () => {
    const result = await execute('query { audibleAccount { marketplace } }')

    expect(result.errors).toBeUndefined()
    expect(result.data?.audibleAccount).toBeNull()
  })

  test('refuses a code when no sign-in is in progress', async () => {
    const result = await execute(
      'mutation { completeAudibleLogin(authorizationCode: "the-code") { marketplace } }',
    )

    expect(codeOf(result)).toBe('AUDIBLE_NO_PENDING_LOGIN')
  })

  test('refuses an empty code as bad input', async () => {
    const result = await execute(
      'mutation { completeAudibleLogin(authorizationCode: "  ") { marketplace } }',
    )

    expect(codeOf(result)).toBe('BAD_USER_INPUT')
  })

  test('forgets the connection on request, and says when there was none', async () => {
    await connect()

    const first = await execute('mutation { disconnectAudible }')
    const second = await execute('mutation { disconnectAudible }')

    expect(first.data?.disconnectAudible).toBe(true)
    expect(second.data?.disconnectAudible).toBe(false)
  })
})

describe('listing the Audible library through the API', () => {
  test('refuses when no account is connected', async () => {
    const result = await execute('query { audibleLibrary { asin } }')

    expect(codeOf(result)).toBe('AUDIBLE_NOT_CONNECTED')
  })

  test('proposes the library without cataloguing anything', async () => {
    await connect()
    items = [anItem({ series: { name: 'Chronique du tueur de roi', position: 1 } })]

    const result = await execute(
      'query { audibleLibrary { asin title authors narrators durationMinutes coverUrl seriesName volume status alreadyInLibrary } }',
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.audibleLibrary).toEqual([
      {
        asin: 'B002V1OF70',
        title: 'Le Nom du vent',
        authors: ['Patrick Rothfuss'],
        narrators: ['Bernard Gabay'],
        durationMinutes: 1770,
        coverUrl: 'https://m.media-amazon.com/images/I/900.jpg',
        seriesName: 'Chronique du tueur de roi',
        volume: 1,
        status: 'TO_READ',
        alreadyInLibrary: false,
      },
    ])
    const library = await execute('query { library { books { id } } }')
    expect(library.data?.library).toEqual([])
  })

  // Amazon refuses for reasons this server cannot tell apart — a revoked device,
  // a changed password, an outage. The app's answer to all of them is the same.
  test('reports one error when Amazon refuses the call', async () => {
    await connect()
    libraryFails = new Error('Audible API error: 401 Unauthorized')

    const result = await execute('query { audibleLibrary { asin } }')

    expect(codeOf(result)).toBe('AUDIBLE_UNAVAILABLE')
  })
})

describe('importing through the API', () => {
  test('catalogues the ticked titles as audiobooks and returns them', async () => {
    await connect()
    items = [anItem(), anItem({ asin: 'B00X57B4KE', title: 'La Peur du sage' })]

    const result = await execute(
      'mutation { importAudibleBooks(asins: ["B002V1OF70"]) { title format status coverUrl } }',
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.importAudibleBooks).toEqual([
      {
        title: 'Le Nom du vent',
        format: 'AUDIOBOOK',
        status: 'TO_READ',
        coverUrl: 'https://m.media-amazon.com/images/I/900.jpg',
      },
    ])
  })

  // Audible is the only source that ever names a narrator: a cover does not say
  // who reads the recording, so an import that dropped them lost them for good.
  test('keeps the narrators of an imported recording on the book', async () => {
    await connect()
    items = [anItem({ narrators: ['Bernard Gabay', 'Marie Bouvier'] })]

    const result = await execute(
      'mutation { importAudibleBooks(asins: ["B002V1OF70"]) { narrators } }',
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.importAudibleBooks).toEqual([
      { narrators: ['Bernard Gabay', 'Marie Bouvier'] },
    ])
  })

  test('puts the imported book in the library it was imported into', async () => {
    await connect()
    items = [anItem()]

    await execute('mutation { importAudibleBooks(asins: ["B002V1OF70"]) { id } }')

    const library = await execute('query { library { books { title format } } }')
    expect(library.data?.library).toEqual([
      { books: [{ title: 'Le Nom du vent', format: 'AUDIOBOOK' }] },
    ])
  })

  // The library is re-read on import, so a title catalogued in between is
  // recognized and skipped rather than duplicated.
  test('creates no duplicate when the same list is imported twice', async () => {
    await connect()
    items = [anItem()]

    await execute('mutation { importAudibleBooks(asins: ["B002V1OF70"]) { id } }')
    const second = await execute('mutation { importAudibleBooks(asins: ["B002V1OF70"]) { id } }')

    expect(second.errors).toBeUndefined()
    expect(second.data?.importAudibleBooks).toEqual([])
  })

  test('marks an already catalogued title in the picker rather than hiding it', async () => {
    await connect()
    items = [anItem()]
    await execute('mutation { importAudibleBooks(asins: ["B002V1OF70"]) { id } }')

    const result = await execute('query { audibleLibrary { title alreadyInLibrary } }')

    expect(result.data?.audibleLibrary).toEqual([
      { title: 'Le Nom du vent', alreadyInLibrary: true },
    ])
  })

  // The ASIN is checked at the door: it addresses a row in somebody's Amazon
  // library, and a free-text identifier has no business reaching the client.
  test('refuses an identifier that is not an ASIN, as bad input', async () => {
    await connect()

    const result = await execute('mutation { importAudibleBooks(asins: ["nope"]) { id } }')

    expect(codeOf(result)).toBe('BAD_USER_INPUT')
  })

  test('refuses when no account is connected', async () => {
    const result = await execute('mutation { importAudibleBooks(asins: ["B002V1OF70"]) { id } }')

    expect(codeOf(result)).toBe('AUDIBLE_NOT_CONNECTED')
  })
})

describe('governing the nightly sync through the API', () => {
  // The switch a reader flips must read back as the setting the app draws, and
  // a fresh connection is already following them — that is what linking asked
  // for.
  test('a new connection syncs nightly', async () => {
    await connect()

    const result = await execute('query { audibleAccount { autoSync } }')

    expect(result.data?.audibleAccount).toEqual({ autoSync: true })
  })

  test('turning it off is what the account reads back', async () => {
    await connect()

    const turnedOff = await execute('mutation { setAudibleAutoSync(enabled: false) { autoSync } }')

    expect(turnedOff.errors).toBeUndefined()
    expect(turnedOff.data?.setAudibleAutoSync).toEqual({ autoSync: false })
    const account = await execute('query { audibleAccount { autoSync } }')
    expect(account.data?.audibleAccount).toEqual({ autoSync: false })
  })

  test('refuses to keep a setting no library backs', async () => {
    const result = await execute('mutation { setAudibleAutoSync(enabled: false) { autoSync } }')

    expect(codeOf(result)).toBe('AUDIBLE_NOT_CONNECTED')
  })
})

describe('asking for a pass right now', () => {
  test('catalogues what was bought and says how much it brought back', async () => {
    await connect()
    items = [anItem(), anItem({ asin: 'B00X57B4KE', title: 'La Peur du sage' })]

    const result = await execute(
      'mutation { syncAudibleNow { imported updated account { lastImportedAt } } }',
    )

    expect(result.errors).toBeUndefined()
    // The account comes back with the pass, so the screen that asked redraws its
    // date without a second round trip.
    expect(result.data?.syncAudibleNow).toMatchObject({
      imported: 2,
      updated: 0,
      account: { lastImportedAt: expect.any(String) },
    })
  })

  // The switch governs what happens unasked. A reader who turned the nightly
  // pass off and then pressed the button meant it.
  test('runs even with the nightly sync turned off', async () => {
    await connect()
    await execute('mutation { setAudibleAutoSync(enabled: false) { autoSync } }')
    items = [anItem()]

    const result = await execute('mutation { syncAudibleNow { imported } }')

    expect(result.errors).toBeUndefined()
    expect(result.data?.syncAudibleNow).toMatchObject({ imported: 1 })
  })

  test('moves a book already catalogued to the status Audible reports', async () => {
    await connect()
    items = [anItem()]
    await execute('mutation { importAudibleBooks(asins: ["B002V1OF70"]) { id } }')
    items = [
      anItem({
        listeningStatus: {
          isFinished: true,
          percentComplete: 100,
          finishedAt: new Date('2026-04-02T10:00:00.000Z'),
        },
      } as Partial<AudibleItem>),
    ]

    const result = await execute('mutation { syncAudibleNow { imported updated } }')

    expect(result.errors).toBeUndefined()
    expect(result.data?.syncAudibleNow).toMatchObject({ imported: 0, updated: 1 })
  })

  test('refuses when no account is connected', async () => {
    const result = await execute('mutation { syncAudibleNow { imported } }')

    expect(codeOf(result)).toBe('AUDIBLE_NOT_CONNECTED')
  })

  test('reports one error when Amazon refuses the call', async () => {
    await connect()
    libraryFails = new Error('device revoked')

    const result = await execute('mutation { syncAudibleNow { imported } }')

    expect(codeOf(result)).toBe('AUDIBLE_UNAVAILABLE')
  })
})
