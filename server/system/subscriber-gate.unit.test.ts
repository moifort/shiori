import { describe, expect, test } from 'bun:test'
import { isSubscriptionRequired, requireSubscriber } from '~/system/subscriber-gate'

describe('the paid model calls of a request', () => {
  test('are let through for a subscriber', async () => {
    await requireSubscriber({ _isSubscriber: async () => true })
  })

  test('are refused for a caller without Premium', async () => {
    const refusal = await requireSubscriber({ _isSubscriber: async () => false }).catch(
      (error) => error,
    )
    expect(isSubscriptionRequired(refusal)).toBe(true)
  })

  test('are let through outside a request, where the passes choose their readers', async () => {
    await requireSubscriber({})
    await requireSubscriber(undefined)
  })
})
