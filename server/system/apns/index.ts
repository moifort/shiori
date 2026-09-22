import { createPrivateKey, sign } from 'node:crypto'
import { connect } from 'node:http2'
import { config } from '~/system/config/index'
import { createLogger } from '~/system/logger'

const logger = createLogger('apns')

/** The app every notification is addressed to: APNs routes on the topic. */
const TOPIC = 'com.polyforms.shiori.app'

/** Which APNs gateway a device token belongs to. A build signed for
 *  development gets a sandbox token, which the production gateway rejects, and
 *  the reverse: the app says which it is when it registers. */
export type PushEnvironment = 'sandbox' | 'production'

export type PushMessage = {
  title: string
  body: string
  /** Notifications of one kind stack together in the notification centre. */
  threadId?: string
  /** Handed to the app when the notification is tapped: where to open. */
  link?: string
}

/** What became of one push. `unregistered` means the token is dead — the app
 *  was deleted, or notifications turned off — and must be forgotten.
 *  `unconfigured` means no APNs key was deployed: the alert is only logged. */
export type PushOutcome = 'sent' | 'unregistered' | 'failed' | 'unconfigured'

const HOSTS: Record<PushEnvironment, string> = {
  production: 'https://api.push.apple.com',
  sandbox: 'https://api.sandbox.push.apple.com',
}

/** A provider token lives an hour and APNs refuses one refreshed more than
 *  once every twenty minutes, so one is kept and reused for fifty. */
const TOKEN_LIFETIME_MS = 50 * 60 * 1000
let cachedToken: { value: string; issuedAt: number } | undefined

export namespace Apns {
  /** Send one notification to one device, over HTTP/2 as APNs requires. */
  export const send = async (
    device: { token: string; environment: PushEnvironment },
    message: PushMessage,
  ): Promise<PushOutcome> => {
    const { apnsKeyId, apnsPrivateKey, apnsTeamId } = config()
    if (!apnsKeyId || !apnsPrivateKey || !apnsTeamId) {
      logger.info('push not configured, alert only logged', { title: message.title })
      return 'unconfigured'
    }
    const payload = JSON.stringify({
      aps: {
        alert: { title: message.title, body: message.body },
        sound: 'default',
        ...(message.threadId ? { 'thread-id': message.threadId } : {}),
      },
      ...(message.link ? { link: message.link } : {}),
    })
    try {
      const { status, reason } = await post(HOSTS[device.environment], device.token, payload, {
        authorization: `bearer ${providerToken(apnsTeamId, apnsKeyId, apnsPrivateKey)}`,
      })
      if (status === 200) return 'sent'
      if (status === 410 || reason === 'BadDeviceToken' || reason === 'Unregistered')
        return 'unregistered'
      logger.warn('push refused', { status, reason, environment: device.environment })
      return 'failed'
    } catch (error) {
      logger.warn('push failed', { error, environment: device.environment })
      return 'failed'
    }
  }
}

const post = (
  host: string,
  token: string,
  payload: string,
  headers: Record<string, string>,
): Promise<{ status: number; reason?: string }> =>
  new Promise((resolve, reject) => {
    const session = connect(host)
    session.on('error', reject)
    const request = session.request({
      ':method': 'POST',
      ':path': `/3/device/${token}`,
      'apns-topic': TOPIC,
      'apns-push-type': 'alert',
      'content-type': 'application/json',
      ...headers,
    })
    let status = 0
    let body = ''
    request.setEncoding('utf8')
    request.on('response', (responseHeaders) => {
      status = Number(responseHeaders[':status'])
    })
    request.on('data', (chunk: string) => {
      body += chunk
    })
    request.on('end', () => {
      session.close()
      let reason: string | undefined
      try {
        reason = body ? (JSON.parse(body) as { reason?: string }).reason : undefined
      } catch {
        reason = undefined
      }
      resolve({ status, reason })
    })
    request.on('error', (error) => {
      session.close()
      reject(error)
    })
    request.end(payload)
  })

const providerToken = (teamId: string, keyId: string, privateKey: string): string => {
  const now = Date.now()
  if (cachedToken && now - cachedToken.issuedAt < TOKEN_LIFETIME_MS) return cachedToken.value
  const encode = (value: object) => Buffer.from(JSON.stringify(value)).toString('base64url')
  const header = encode({ alg: 'ES256', kid: keyId })
  const claims = encode({ iss: teamId, iat: Math.floor(now / 1000) })
  const signature = sign('sha256', Buffer.from(`${header}.${claims}`), {
    key: createPrivateKey(privateKey),
    dsaEncoding: 'ieee-p1363',
  }).toString('base64url')
  cachedToken = { value: `${header}.${claims}.${signature}`, issuedAt: now }
  return cachedToken.value
}
