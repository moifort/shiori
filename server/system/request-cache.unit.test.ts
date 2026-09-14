import { afterEach, describe, expect, test } from 'bun:test'
import { evictFromRequestCache, isInRequestCache, memoizedPerRequest } from './request-cache'

// The request cache reads the current H3 event via the auto-imported useEvent().
// In unit tests there is no request, so we stub a fake event on the global.
const withRequest = (context: Record<string, unknown> = {}) => {
  ;(globalThis as unknown as { useEvent: () => unknown }).useEvent = () => ({ context })
}

describe('memoizedPerRequest', () => {
  afterEach(() => {
    delete (globalThis as unknown as { useEvent?: unknown }).useEvent
  })

  test('runs the factory once and reuses the value within a request', () => {
    withRequest()
    let calls = 0
    const read = () => ++calls
    expect(memoizedPerRequest('k', read)).toBe(1)
    expect(memoizedPerRequest('k', read)).toBe(1)
    expect(calls).toBe(1)
  })

  test('caches the promise so concurrent reads dedupe', async () => {
    withRequest()
    let calls = 0
    const read = () => {
      calls++
      return Promise.resolve('value')
    }
    const [a, b] = await Promise.all([memoizedPerRequest('p', read), memoizedPerRequest('p', read)])
    expect(a).toBe('value')
    expect(b).toBe('value')
    expect(calls).toBe(1)
  })

  test('different keys are cached independently', () => {
    withRequest()
    let calls = 0
    memoizedPerRequest('a', () => ++calls)
    memoizedPerRequest('b', () => ++calls)
    expect(calls).toBe(2)
  })

  test('isInRequestCache and evictFromRequestCache track entries', () => {
    withRequest()
    memoizedPerRequest('k', () => 1)
    expect(isInRequestCache('k')).toBe(true)
    evictFromRequestCache('k')
    expect(isInRequestCache('k')).toBe(false)
  })

  test('runs uncached when there is no request context', () => {
    let calls = 0
    memoizedPerRequest('k', () => ++calls)
    memoizedPerRequest('k', () => ++calls)
    expect(calls).toBe(2)
    expect(isInRequestCache('k')).toBe(false)
  })
})
