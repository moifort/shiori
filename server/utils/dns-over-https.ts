import { request } from 'node:https'
import type { LookupFunction } from 'node:net'
import { createLogger } from '~/system/logger'
import { isTimeout } from '~/utils/fetch'

const logger = createLogger('dns-over-https')

/** Cloudflare's resolver, addressed by IP so that reaching it needs no name lookup. */
const CLOUDFLARE_DNS_URL = 'https://1.1.1.1/dns-query'

/** Cloudflare answers in tens of milliseconds; past this the platform's resolver is tried. */
const RESOLVE_TIMEOUT_MS = 2000

/** An IPv4 address record in a DNS answer; aliases (CNAME, 5) come before it. */
const ADDRESS_RECORD = 1

type DnsJsonAnswer = { Answer?: { type: number; data: string }[] }

/** The IPv4 address Cloudflare's public resolver gives for a host name, asked
 *  over HTTPS; undefined when it has none or cannot be reached.
 *
 *  For the hosts whose name servers do not answer the platform's resolver: Cloud
 *  Run resolves through Google Public DNS, which the BnF's name servers leave
 *  unanswered most of the time.
 *
 *  Never throws: a missing address sends the caller back to the platform's resolver. */
export const addressFromCloudflare = async (hostname: string): Promise<string | undefined> => {
  const url = `${CLOUDFLARE_DNS_URL}?${new URLSearchParams({ name: hostname, type: 'A' })}`
  try {
    const response = await fetch(url, {
      headers: { accept: 'application/dns-json' },
      signal: AbortSignal.timeout(RESOLVE_TIMEOUT_MS),
    })
    if (!response.ok) {
      logger.warn('Cloudflare name lookup failed', { status: response.status, hostname })
      return undefined
    }
    const { Answer } = (await response.json()) as DnsJsonAnswer
    return Answer?.find(({ type }) => type === ADDRESS_RECORD)?.data
  } catch (error) {
    if (isTimeout(error)) logger.info('Cloudflare name lookup timed out', { hostname })
    else logger.warn('Cloudflare name lookup failed', { error, hostname })
    return undefined
  }
}

/** A GET of an HTTPS URL at a known address, without resolving its host name.
 *  The TLS handshake still names the host and checks its certificate against
 *  it, so the address only says where to connect, never whom to trust.
 *
 *  Unlike `fetch`, it sends no header of its own: a server that refuses a request
 *  without a user agent, as the BnF does with a 403, needs one in `headers`.
 *
 *  Fails like `fetch` on a timeout: a `DOMException` named `TimeoutError`. */
export const fetchFromAddress = (
  url: string,
  address: string,
  { timeoutMs, headers }: { timeoutMs: number; headers: Record<string, string> },
): Promise<Response> =>
  new Promise((resolve, reject) => {
    // Node asks for every address when it may try several families in turn.
    const lookup = ((_hostname, options, callback) => {
      if (options.all) callback(null, [{ address, family: 4 }])
      else callback(null, address, 4)
    }) as LookupFunction
    const outgoing = request(url, { lookup, headers }, (incoming) => {
      const chunks: Buffer[] = []
      incoming.on('data', (chunk: Buffer) => chunks.push(chunk))
      incoming.on('error', reject)
      incoming.on('end', () => {
        clearTimeout(timer)
        const status = incoming.statusCode ?? 502
        const bodyless = status === 204 || status === 304
        resolve(new Response(bodyless ? null : Buffer.concat(chunks), { status }))
      })
    })
    const timer = setTimeout(
      () => outgoing.destroy(new DOMException(`${url} took too long`, 'TimeoutError')),
      timeoutMs,
    )
    outgoing.on('error', (error) => {
      clearTimeout(timer)
      reject(error)
    })
    outgoing.end()
  })
