import { createPrivateKey, createSign } from 'node:crypto'
import { type KindleCredentials, landingUrlOf, library, login, register } from 'kindle-api-ts'
import { positionIn } from '~/domain/kindle/infrastructure/sidecar'
import type { KindleMarketplace } from '~/domain/kindle/types'

/** The whole surface of `kindle-api-ts` this domain uses, behind one module,
 *  with the one call it does not make yet.
 *
 *  It exists to be mocked: every call here reaches Amazon and would need a real
 *  account to answer. Tests replace this module and nothing else, so the
 *  mapping, the sealing and the write paths are all exercised for real. */
export { library, login, register }

/** Where Amazon sends the browser back once the reader has signed in. The app
 *  watches for exactly this URL to know the sign-in is done. */
export const landingUrlFor = (marketplace: KindleMarketplace): string => landingUrlOf(marketplace)

const SIDECAR_URL = 'https://cde-ta-g7g.amazon.com/FionaCDEServiceEngine/sidecar'
const SIDECAR_TIMEOUT_MS = 10_000

/** A device call signs its method, path, time and token with the device's key. */
const signedHeaders = (credentials: KindleCredentials, path: string) => {
  const raw = credentials.devicePrivateKey
  const key = raw.includes('BEGIN')
    ? createPrivateKey(raw)
    : createPrivateKey({ key: Buffer.from(raw, 'base64'), format: 'der', type: 'pkcs8' })
  const time = new Date().toISOString()
  const signature = createSign('RSA-SHA256')
    .update(['GET', path, time, '', credentials.adpToken].join('\n'))
    .sign(key, 'base64')
  return {
    'x-adp-token': credentials.adpToken,
    'x-adp-alg': 'SHA256withRSA:1.0',
    'x-adp-signature': `${signature}:${time}`,
  }
}

/** Where Whispersync last saw the reader in a title, as the device API answers
 *  it. Undefined when its sidecar holds none.
 *
 *  @throws when Amazon refuses the call */
export const readingPosition = async (
  credentials: KindleCredentials,
  asin: string,
): Promise<number | undefined> => {
  const url = new URL(SIDECAR_URL)
  url.search = new URLSearchParams({ type: 'EBOK', key: asin }).toString()
  const response = await fetch(url, {
    headers: signedHeaders(credentials, `${url.pathname}${url.search}`),
    signal: AbortSignal.timeout(SIDECAR_TIMEOUT_MS),
  })
  // A title with no sidecar was never opened: there is no position to read.
  if (response.status === 404) return undefined
  if (!response.ok) throw new Error(`Kindle sidecar answered ${response.status}`)
  return positionIn(Buffer.from(await response.arrayBuffer()))
}
