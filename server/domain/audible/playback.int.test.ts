import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { randomBytes } from 'node:crypto'
import { LicenseDeniedError, type PlaybackLicense } from 'audible-api-ts'
import type { AudibleAsin } from '~/domain/audible/types'
import type { UserId } from '~/domain/shared/types'
import { fakeAudibleApi, stageAudibleApi } from '~/test/fake-audible-api'
import { fakeDb, resetFakeFirestore, startFakeRequest } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
const audibleKey = randomBytes(32).toString('base64')
mock.module('~/system/config', () => ({ config: () => ({ audibleKey }) }))
mock.module('~/domain/audible/infrastructure/audible-api', () => fakeAudibleApi)

const { AudibleCommand } = await import('~/domain/audible/command')
const { AudibleUseCase } = await import('~/domain/audible/use-case')
const { AudibleQuery } = await import('~/domain/audible/query')
const { openCredentials } = await import('~/domain/audible/infrastructure/credentials-vault')

const reader = 'reader-1' as UserId
const asin = 'B0H95GDVTN' as AudibleAsin

const credentialsWith = (accessToken: string) => ({
  accessToken,
  refreshToken: 'Atnr|the-refresh-token',
  adpToken: '{enc:token}',
  devicePrivateKey: 'key',
  serial: 'SERIAL1',
  locale: 'fr',
  expiresAt: new Date('2026-11-18T12:00:00.000Z'),
})

const license: PlaybackLicense = {
  asin,
  acr: 'CR!ACR',
  drm: 'FairPlay',
  streamUrl: 'https://example.cloudfront.net/title.m3u8',
  certificate: 'Q0VSVA==',
  durationMs: 43_221_151,
  chapters: [{ title: 'Chapitre 1', startMs: 0, lengthMs: 774_340 }],
  codec: 'mp4a.40.42',
  lastPosition: { positionMs: 35_340_728, lastUpdatedAt: new Date('2026-11-18T10:04:01.809Z') },
}

/** What the fake Amazon was handed, and the token it answers with. */
let answeredToken = 'access-1'
let refusal: Error | undefined
const keyCalls: string[] = []
const savedPositions: unknown[] = []
const consumptions: (string | undefined)[] = []
const drms: (string | undefined)[] = []

beforeEach(() => {
  resetFakeFirestore()
  startFakeRequest()
  answeredToken = 'access-1'
  refusal = undefined
  keyCalls.length = 0
  savedPositions.length = 0
  consumptions.length = 0
  drms.length = 0
  stageAudibleApi({
    login: async () => ({
      loginUrl: 'https://www.amazon.fr/ap/signin',
      session: { codeVerifier: 'v', serial: 'SERIAL1', locale: 'fr', createdAt: new Date() },
      cookies: [],
    }),
    register: async () => credentialsWith('access-1'),
    landingUrlOf: () => 'https://www.amazon.fr/ap/maplanding',
    playbackLicense: async (
      _credentials: unknown,
      _asin: string,
      options?: { consumption?: string; drm?: string },
    ) => {
      consumptions.push(options?.consumption)
      drms.push(options?.drm)
      if (refusal) throw refusal
      return { license, credentials: credentialsWith(answeredToken) }
    },
    fairPlayKey: async (
      _credentials: unknown,
      _asin: string,
      spc: string,
      options?: { consumption?: string },
    ) => {
      keyCalls.push(spc)
      consumptions.push(options?.consumption)
      return { ckc: 'Q0tD', credentials: credentialsWith(answeredToken) }
    },
    widevineKey: async (
      _credentials: unknown,
      _asin: string,
      challenge: string,
      options?: { consumption?: string },
    ) => {
      keyCalls.push(challenge)
      consumptions.push(options?.consumption)
      return { license: 'TElD', credentials: credentialsWith(answeredToken) }
    },
    savePosition: async (_credentials: unknown, position: unknown) => {
      savedPositions.push(position)
      return { credentials: credentialsWith(answeredToken) }
    },
  })
})

const connect = async () => {
  await AudibleCommand.startLogin(reader, 'fr')
  await AudibleCommand.completeLogin(reader, 'the-code')
}

const storedAccessToken = async () => {
  const account = await AudibleQuery.accountOf(reader)
  return account && openCredentials(account.credentials).accessToken
}

describe('playing a title', () => {
  test('answers the stream, the chapters and where the reader stopped', async () => {
    await connect()
    const playback = await AudibleUseCase.playback(reader, asin)

    expect(playback).toEqual({
      asin,
      contentReference: 'CR!ACR',
      streamUrl: 'https://example.cloudfront.net/title.m3u8',
      certificate: 'Q0VSVA==',
      durationMs: 43_221_151,
      chapters: [{ title: 'Chapitre 1', startMs: 0, lengthMs: 774_340 }],
      position: { positionMs: 35_340_728, savedAt: new Date('2026-11-18T10:04:01.809Z') },
    })
  })

  test('is refused without an account', async () => {
    expect(await AudibleUseCase.playback(reader, asin)).toBe('not-connected')
    expect(await AudibleUseCase.fairPlayKey(reader, asin, 'U1BD')).toBe('not-connected')
    expect(await AudibleUseCase.widevineKey(reader, asin, 'Q0hBTA==')).toBe('not-connected')
    expect(
      await AudibleUseCase.savePosition(reader, {
        asin,
        contentReference: 'CR!ACR',
        positionMs: 1,
      }),
    ).toBe('not-connected')
  })

  test('says denied when Amazon grants no licence', async () => {
    await connect()
    refusal = new LicenseDeniedError(asin, 'Denied', ['quota'])

    expect(await AudibleUseCase.playback(reader, asin)).toBe('denied')
  })

  test('lets any other Amazon failure through', async () => {
    await connect()
    refusal = new Error('Audible API error: 503')

    await expect(AudibleUseCase.playback(reader, asin)).rejects.toThrow('503')
  })

  test('relays the key request and answers the content key', async () => {
    await connect()

    expect(await AudibleUseCase.fairPlayKey(reader, asin, 'U1BD')).toBe('Q0tD')
    expect(keyCalls).toEqual(['U1BD'])
  })

  test('asks Amazon for FairPlay unless the device plays Widevine', async () => {
    await connect()
    await AudibleUseCase.playback(reader, asin)
    await AudibleUseCase.playback(reader, asin, { drm: 'widevine' })

    expect(drms).toEqual(['FairPlay', 'Widevine'])
  })

  test('relays a Widevine key request, to keep when offline', async () => {
    await connect()

    expect(await AudibleUseCase.widevineKey(reader, asin, 'Q0hBTA==', { offline: true })).toBe(
      'TElD',
    )
    expect(keyCalls).toEqual(['Q0hBTA=='])
    expect(consumptions).toEqual(['Download'])
  })

  test('asks for a download licence and a key to keep when offline', async () => {
    await connect()
    await AudibleUseCase.playback(reader, asin)
    await AudibleUseCase.playback(reader, asin, { offline: true })
    await AudibleUseCase.fairPlayKey(reader, asin, 'U1BD', { offline: true })

    expect(consumptions).toEqual(['Streaming', 'Download', 'Download'])
  })

  test('saves the position against the licence’s content reference', async () => {
    await connect()
    const saved = await AudibleUseCase.savePosition(reader, {
      asin,
      contentReference: 'CR!ACR',
      positionMs: 61_000,
    })

    expect(saved).toBe('saved')
    expect(savedPositions).toEqual([{ asin, acr: 'CR!ACR', positionMs: 61_000 }])
  })
})

describe('the access token', () => {
  test('is written back when Amazon rotated it', async () => {
    await connect()
    answeredToken = 'access-2'
    await AudibleUseCase.savePosition(reader, { asin, contentReference: 'CR!ACR', positionMs: 1 })

    startFakeRequest()
    expect(await storedAccessToken()).toBe('access-2')
  })

  test('is left alone, with no write, when it did not rotate', async () => {
    await connect()
    startFakeRequest()
    const before = (await AudibleQuery.accountOf(reader))?.credentials

    startFakeRequest()
    await AudibleUseCase.savePosition(reader, { asin, contentReference: 'CR!ACR', positionMs: 1 })

    startFakeRequest()
    expect((await AudibleQuery.accountOf(reader))?.credentials).toBe(before)
  })
})
