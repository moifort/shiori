import { afterEach, describe, expect, spyOn, test } from 'bun:test'
import { addressFromCloudflare } from '~/utils/dns-over-https'

const cloudflareAnswers = (body: unknown) =>
  spyOn(globalThis, 'fetch').mockImplementation(
    (async () => new Response(JSON.stringify(body))) as unknown as typeof fetch,
  )

afterEach(() => {
  ;(globalThis.fetch as unknown as { mockRestore?: () => void }).mockRestore?.()
})

describe('addressFromCloudflare', () => {
  test('takes the address past the aliases', async () => {
    cloudflareAnswers({
      Status: 0,
      Answer: [
        { type: 5, data: 'front.example.org.' },
        { type: 1, data: '192.0.2.7' },
      ],
    })

    expect(await addressFromCloudflare('www.example.org')).toBe('192.0.2.7')
  })

  test('has no address for a name Cloudflare could not resolve', async () => {
    cloudflareAnswers({ Status: 2 })

    expect(await addressFromCloudflare('www.example.org')).toBeUndefined()
  })

  test('has no address when Cloudflare cannot be reached', async () => {
    spyOn(globalThis, 'fetch').mockImplementation((async () => {
      throw new TypeError('fetch failed')
    }) as unknown as typeof fetch)

    expect(await addressFromCloudflare('www.example.org')).toBeUndefined()
  })
})
