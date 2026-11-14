import { scopedAccessToken } from '~/system/google-token'
import { createLogger } from '~/system/logger'
import { parseSubscription, type SubscriptionPurchaseV2 } from './subscription'
import { PACKAGE_NAME, type PlaySubscription } from './types'

const logger = createLogger('google-play')

// The Play Developer API only takes a token carrying its own scope, for the runtime's service
// account, which Play Console must list as a user with the "View financial data" and "Manage
// orders and subscriptions" permissions.
const accessToken = () => scopedAccessToken('https://www.googleapis.com/auth/androidpublisher')

const API = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE_NAME}`

export namespace GooglePlay {
  // What Google says a purchase token bought. 'invalid-token' when Google does not know it —
  // a token made up, or one from another app.
  export const verifySubscription = async (
    purchaseToken: string,
  ): Promise<PlaySubscription | 'invalid-token'> => {
    const response = await fetch(
      `${API}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`,
      { headers: { authorization: `Bearer ${await accessToken()}` } },
    )
    if (response.status === 400 || response.status === 404 || response.status === 410) {
      return 'invalid-token'
    }
    if (!response.ok) {
      logger.error('play subscription lookup failed', { status: response.status })
      throw new Error(`Play subscriptionsv2.get answered ${response.status}`)
    }
    const purchase = (await response.json()) as SubscriptionPurchaseV2
    return parseSubscription(purchaseToken, purchase, new Date()) ?? 'invalid-token'
  }

  // Tells Play the purchase was granted. Without it Play refunds the purchase after three days,
  // so a failure is logged and retried on the next sync rather than failing the grant.
  export const acknowledge = async (subscription: PlaySubscription): Promise<void> => {
    const url =
      `${API}/purchases/subscriptions/${encodeURIComponent(subscription.productId)}` +
      `/tokens/${encodeURIComponent(subscription.purchaseToken)}:acknowledge`
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${await accessToken()}`,
        'content-type': 'application/json',
      },
      body: '{}',
    })
    if (!response.ok) {
      logger.warn('play acknowledgement failed', {
        status: response.status,
        productId: subscription.productId,
      })
    }
  }
}
