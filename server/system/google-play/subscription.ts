import type { PlaySubscription } from './types'

/** Google's `SubscriptionPurchaseV2`, reduced to what is read from it. */
export type SubscriptionPurchaseV2 = {
  startTime?: string
  subscriptionState?: string
  acknowledgementState?: string
  externalAccountIdentifiers?: { obfuscatedExternalAccountId?: string }
  lineItems?: {
    productId?: string
    expiryTime?: string
    /** The offer the line item was bought through; absent on the base plan alone. */
    offerDetails?: { offerId?: string }
    /** Which phase of that offer runs now: exactly one of its keys is set. */
    offerPhase?: { freeTrial?: object; introductoryPrice?: object; basePrice?: object }
  }[]
}

type LineItem = NonNullable<SubscriptionPurchaseV2['lineItems']>[number]

// Whether a line item is still in its free trial. Google says so in `offerPhase`. A line item
// bought through an offer that does not say which phase it is in is read as a trial: taking a
// paid period for a trial only delays a grant, while the reverse hands it away. The base plan
// bought with no offer is paid from its first day.
export const inFreeTrial = (item: LineItem): boolean =>
  item.offerPhase
    ? item.offerPhase.freeTrial !== undefined
    : item.offerDetails?.offerId !== undefined

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
    .map((item) => ({
      productId: item.productId,
      expiresAt: dateOf(item.expiryTime),
      freeTrial: inFreeTrial(item),
    }))
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
    ...(latest.freeTrial ? { freeTrial: true } : {}),
    needsAcknowledgement: purchase.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_PENDING',
  }
}
