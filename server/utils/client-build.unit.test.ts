import { describe, expect, test } from 'bun:test'
import { clientBuildOf, userAgentOf } from '~/utils/client-build'

describe('clientBuildOf', () => {
  test('a build run from Xcode is a debug build', () => {
    expect(clientBuildOf('Shiori/1 CFNetwork/3896.200.61 Darwin/27.2.0')).toEqual({
      client: 'Shiori/1',
      debugBuild: true,
    })
  })

  test('a TestFlight or App Store build is not', () => {
    expect(clientBuildOf('Shiori/1572 CFNetwork/3860.600.12 Darwin/25.5.0')).toEqual({
      client: 'Shiori/1572',
      debugBuild: false,
    })
    expect(clientBuildOf('Shiori/12 CFNetwork/3860.600.12 Darwin/25.5.0').debugBuild).toBe(false)
  })

  test('another client keeps its first token', () => {
    expect(clientBuildOf('okhttp/5.3.0')).toEqual({ client: 'okhttp/5.3.0', debugBuild: false })
  })

  test('no user agent is an unknown client', () => {
    expect(clientBuildOf(undefined)).toEqual({ client: 'unknown', debugBuild: false })
    expect(clientBuildOf('  ')).toEqual({ client: 'unknown', debugBuild: false })
  })
})

describe('userAgentOf', () => {
  test('reads the header off the event, and nothing off an event with no request', () => {
    expect(userAgentOf({ node: { req: { headers: { 'user-agent': 'Shiori/1' } } } })).toBe(
      'Shiori/1',
    )
    expect(userAgentOf({})).toBeUndefined()
    expect(userAgentOf(undefined)).toBeUndefined()
  })
})
