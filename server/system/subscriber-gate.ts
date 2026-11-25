// Shiori has no free plan: the paid model calls a request makes are a subscriber's.
// The GraphQL route hands each request a way to ask whether its caller is Premium; a
// grounded search or a Claude call made inside a request whose caller is not is refused
// here, before anything is billed. Outside a request (the scheduled passes, migrations,
// tests) nothing is asked: those passes choose their readers themselves.

/** What the GraphQL route leaves on a request's context. */
export type SubscriberGateContext = { _isSubscriber?: () => Promise<boolean> }

/** A paid model call refused because the caller holds no Premium. Grouped as one issue,
 *  whichever caller hit it: only builds without the subscription wall can reach it. */
export class SubscriptionRequired extends Error {
  readonly fingerprint = ['subscription-required']
  constructor() {
    super('A paid model call needs an active subscription')
    this.name = 'SubscriptionRequired'
  }
}

export const isSubscriptionRequired = (error: unknown): error is SubscriptionRequired =>
  error instanceof SubscriptionRequired

const contextOrUndefined = (): SubscriberGateContext | undefined => {
  try {
    return useEvent().context as SubscriberGateContext
  } catch {
    return undefined
  }
}

/** Throws `SubscriptionRequired` when the request's caller is not a subscriber. */
export const requireSubscriber = async (
  context: SubscriberGateContext | undefined = contextOrUndefined(),
): Promise<void> => {
  const isSubscriber = context?._isSubscriber
  if (isSubscriber && !(await isSubscriber())) throw new SubscriptionRequired()
}
