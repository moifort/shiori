import { getMessaging } from 'firebase-admin/messaging'
import type { PushMessage, PushOutcome } from '~/system/apns'
import { createLogger } from '~/system/logger'

const logger = createLogger('fcm')

// The error codes FCM answers for a token that will never work again: the app was
// uninstalled, or the token was rotated.
const GONE = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
])

export namespace Fcm {
  /** Send one notification to one Android device through Firebase Cloud Messaging. The
   *  runtime's own credentials sign the request, so nothing needs deploying. */
  export const send = async (token: string, message: PushMessage): Promise<PushOutcome> => {
    try {
      await getMessaging().send({
        token,
        notification: { title: message.title, body: message.body },
        android: {
          priority: 'high',
          notification: {
            channelId: 'alerts',
            ...(message.threadId ? { tag: message.threadId } : {}),
          },
        },
        ...(message.link ? { data: { link: message.link } } : {}),
      })
      return 'sent'
    } catch (error) {
      const code = (error as { code?: string }).code
      if (code && GONE.has(code)) return 'unregistered'
      logger.warn('fcm push failed', { error, code })
      return 'failed'
    }
  }
}
