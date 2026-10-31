/**
 * Asks, against a real Amazon account, whether the reading position Whispersync
 * holds can be read: the web reader's `startReading` answers `lastPageReadData`,
 * but refused a plain session call on 2026-09-30. This tries it with the session
 * token `getDeviceToken` hands out, then signed with the device's key.
 *
 * Run by the account's owner, by hand, never in CI:
 *
 *   bun scripts/kindle-progress-probe.ts fr
 *
 * It prints a sign-in URL; sign in in a browser, then paste back the URL the
 * browser lands on. It prints statuses and percentages — never a title — and
 * keeps nothing: remove the "Shiori Probe" device it registered from the Amazon
 * account afterwards.
 *
 * With `KINDLE_SEALED` and `KINDLE_KEY` in the environment, it uses a stored
 * connection instead of signing in, and registers nothing.
 */
import { createPrivateKey, createSign } from 'node:crypto'
import { createInterface } from 'node:readline/promises'
import type { KindleCredentials, KindleLocale } from 'kindle-api-ts'
import {
  cookieHeaderOf,
  DEVICE,
  KINDLE_LOCALES,
  library,
  login,
  register,
  websiteCookies,
} from 'kindle-api-ts'
import { encryptionKeyOf, unseal } from '~/system/secret-box'

const BROWSER_USER_AGENT =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) ' +
  'Version/18.0 Safari/605.1.15'
const TITLES_TRIED = 8

type Attempt = {
  name: string
  headersFor: (method: string, url: string) => Record<string, string>
}

type LastPageRead = { position?: number; syncTime?: number; deviceName?: string }

const say = (line: string) => process.stdout.write(`${line}\n`)

const digestOf = (key: ReturnType<typeof createPrivateKey>, data: string) =>
  createSign('RSA-SHA256').update(data).sign(key, 'base64')

const privateKeyOf = (raw: string) =>
  raw.includes('BEGIN')
    ? createPrivateKey(raw)
    : createPrivateKey({ key: Buffer.from(raw, 'base64'), format: 'der', type: 'pkcs8' })

/** The two ways Amazon's device calls are signed: Audible's, and the older one
 *  Kindle apps were seen sending. Both sign method, path, time, body and token. */
const signedHeaders = (credentials: KindleCredentials) => {
  const key = privateKeyOf(credentials.devicePrivateKey)
  const modern = (method: string, url: string) => {
    const { pathname, search } = new URL(url)
    const time = new Date().toISOString()
    const data = [method, `${pathname}${search}`, time, '', credentials.adpToken].join('\n')
    return {
      'x-adp-token': credentials.adpToken,
      'x-adp-alg': 'SHA256withRSA:1.0',
      'x-adp-signature': `${digestOf(key, data)}:${time}`,
    }
  }
  const legacy = (method: string, url: string) => {
    const { pathname, search } = new URL(url)
    const time = new Date().toISOString()
    const data = [method, `${pathname}${search}`, time, '', credentials.adpToken].join('\n')
    return {
      'X-ADP-Authentication-Token': credentials.adpToken,
      'X-ADP-Request-Digest': `${digestOf(key, data)}:${time}`,
    }
  }
  return { modern, legacy }
}

const sessionTokenOf = async (host: string, cookie: string, credentials: KindleCredentials) => {
  const url = new URL(`https://${host}/service/web/register/getDeviceToken`)
  url.searchParams.set('serialNumber', credentials.serial)
  url.searchParams.set('deviceType', DEVICE.type)
  const response = await fetch(url, {
    headers: { Cookie: cookie, 'User-Agent': BROWSER_USER_AGENT },
  })
  say(`getDeviceToken on ${host}: ${response.status}`)
  if (!response.ok) return undefined
  const answer = (await response.json().catch(() => undefined)) as
    | { deviceSessionToken?: string }
    | undefined
  return answer?.deviceSessionToken
}

const startReading = async (host: string, asin: string, attempt: Attempt, cookie: string) => {
  const url =
    `https://${host}/service/mobile/reader/startReading` + `?asin=${asin}&clientVersion=2000010`
  const response = await fetch(url, {
    headers: {
      Cookie: cookie,
      'User-Agent': BROWSER_USER_AGENT,
      ...attempt.headersFor('GET', url),
    },
  })
  const text = await response.text()
  const answer = (() => {
    try {
      return JSON.parse(text) as { lastPageReadData?: LastPageRead; metadataUrl?: string }
    } catch {
      return undefined
    }
  })()
  return { status: response.status, answer, refusal: answer ? undefined : text.slice(0, 120) }
}

/** The metadata file is JSONP: its bounds turn a position into a percentage. */
const percentageAt = async (metadataUrl: string, position: number) => {
  const response = await fetch(metadataUrl, { headers: { 'User-Agent': BROWSER_USER_AGENT } })
  if (!response.ok) return undefined
  const text = await response.text()
  const body = text.slice(text.indexOf('{'), text.lastIndexOf('}') + 1)
  const { startPosition = 0, endPosition } = JSON.parse(body) as {
    startPosition?: number
    endPosition?: number
  }
  return endPosition
    ? Math.round(((startPosition + position) / endPosition) * 1000) / 10
    : undefined
}

const sidecarStatus = async (asin: string, attempt: Attempt) => {
  const url = `https://cde-ta-g7g.amazon.com/FionaCDEServiceEngine/sidecar?type=EBOK&key=${asin}`
  const response = await fetch(url, { headers: attempt.headersFor('GET', url) })
  const size = (await response.arrayBuffer()).byteLength
  return `${response.status}, ${size} bytes`
}

const locale = (process.argv[2] ?? 'fr') as KindleLocale

const registeredDevice = async () => {
  const { loginUrl, session } = await login(locale)
  say(`\nSign in here, then paste the URL the browser lands on:\n\n${loginUrl}\n`)
  const prompt = createInterface({ input: process.stdin, output: process.stdout })
  const landing = (await prompt.question('Landing URL: ')).trim()
  prompt.close()

  const code = new URL(landing).searchParams.get('openid.oa2.authorization_code')
  if (!code) throw new Error('No openid.oa2.authorization_code in that URL')

  const registered = await register(code, session, { deviceName: 'Shiori Probe' })
  say('Device registered.')
  return registered
}

const { KINDLE_SEALED: sealed, KINDLE_KEY: sealingKey } = process.env
const credentials: KindleCredentials =
  sealed && sealingKey
    ? JSON.parse(unseal(sealed, encryptionKeyOf(sealingKey)))
    : await registeredDevice()

const cookie = cookieHeaderOf(await websiteCookies(credentials))
const titles = (await library(credentials)).filter(
  ({ category, originType }) => !category.endsWith('Sample') && originType !== 'KindleDictionary',
)
const unread = titles.filter(({ readStatus }) => readStatus !== 'READ').slice(0, TITLES_TRIED - 1)
const read = titles.filter(({ readStatus }) => readStatus === 'READ').slice(0, 1)
const tried = [...unread, ...read]
say(`Titles on the account: ${titles.length}, tried: ${tried.length}`)

const hosts = [
  ...(KINDLE_LOCALES[locale].domain === 'fr' ? ['lire.amazon.fr'] : []),
  `read.amazon.${KINDLE_LOCALES[locale].domain}`,
  'read.amazon.com',
]
const { modern, legacy } = signedHeaders(credentials)

const attemptsOn = async (host: string): Promise<Attempt[]> => {
  const token = await sessionTokenOf(host, cookie, credentials)
  return [
    { name: 'cookies', headersFor: () => ({}) },
    ...(token
      ? [{ name: 'session token', headersFor: () => ({ 'x-adp-session-token': token }) }]
      : []),
    { name: 'signed', headersFor: modern },
    { name: 'signed (legacy)', headersFor: legacy },
  ]
}

const [first] = tried
if (!first) throw new Error('No title to try on this account')

const working: { host: string; attempt: Attempt }[] = []
for (const host of hosts) {
  for (const attempt of await attemptsOn(host)) {
    const { status, answer, refusal } = await startReading(host, first.asin, attempt, cookie)
    const found = answer?.lastPageReadData !== undefined
    say(`${host} / ${attempt.name}: ${status}${found ? ', position answered' : ''}`)
    if (refusal) say(`  ${refusal.replace(/\s+/g, ' ')}`)
    if (found) working.push({ host, attempt })
  }
}

for (const attempt of [
  { name: 'signed', headersFor: modern },
  { name: 'signed (legacy)', headersFor: legacy },
]) {
  say(`sidecar / ${attempt.name}: ${await sidecarStatus(first.asin, attempt)}`)
}

const best = working[0]
if (best) {
  say(`\nPositions through ${best.host} / ${best.attempt.name}:`)
  for (const [index, title] of tried.entries()) {
    const { status, answer } = await startReading(best.host, title.asin, best.attempt, cookie)
    const position = answer?.lastPageReadData?.position
    const percentage =
      answer?.metadataUrl && position !== undefined
        ? await percentageAt(answer.metadataUrl, position)
        : undefined
    const synced = answer?.lastPageReadData?.syncTime
    say(
      `  #${index + 1} ${title.readStatus}: ${status}, ${percentage ?? '?'}%, position ` +
        `${position ?? '?'}, synced ${synced ? new Date(synced).toISOString() : '?'}`,
    )
  }
}

say(
  `\n${best ? 'The position can be read.' : 'No attempt answered a position.'} Remove the ` +
    '"Shiori Probe" device from the Amazon account (Manage your content and devices > Devices).',
)
