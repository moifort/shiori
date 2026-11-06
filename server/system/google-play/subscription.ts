import type { PlaySubscription } from './types'

/** Google's `SubscriptionPurchaseV2`, reduced to what is read from it. */
export type SubscriptionPurchaseV2 = {
  startTime?: string
  subscriptionState?: string
  acknowledgementState?: string
  externalAccountIdentifiers?: { obfuscatedExternalAccountId?: string }
  lineItems?: { productId?: string; expiryTime?: string }[]
}

const dateOf = (value: string | undefined) => {
  if (!value) return undefined
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? undefined : date
}

// Reads what Google answered for a purchase token. The latest line item names the plan
// running and when its paid period ends; a subscription Google calls expired while its period
// still runs was ended early, which is what a refund does.
export const parseSubscription = (
  purchaseToken: string,
  purchase: SubscriptionPurchaseV2,
  now: Date,
): PlaySubscription | undefined => {
  const items = purchase.lineItems ?? []
  const latest = items
    .map((item) => ({ productId: item.productId, expiresAt: dateOf(item.expiryTime) }))
    .sort((a, b) => (b.expiresAt?.getTime() ?? 0) - (a.expiresAt?.getTime() ?? 0))[0]
  if (!latest?.productId) return undefined
  const expired = purchase.subscriptionState === 'SUBSCRIPTION_STATE_EXPIRED'
  const endedEarly = expired && latest.expiresAt !== undefined && latest.expiresAt > now
  const accountToken = purchase.externalAccountIdentifiers?.obfuscatedExternalAccountId
  const startedAt = dateOf(purchase.startTime)
  return {
    productId: latest.productId,
    purchaseToken,
    ...(accountToken ? { accountToken } : {}),
    ...(latest.expiresAt ? { expiresAt: latest.expiresAt } : {}),
    ...(endedEarly ? { revokedAt: now } : {}),
    ...(startedAt ? { startedAt } : {}),
    needsAcknowledgement: purchase.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_PENDING',
  }
}
