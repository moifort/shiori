import { afterEach, beforeEach, describe, expect, test } from 'bun:test'
import { AsyncLocalStorage } from 'node:async_hooks'
import {
  evictFromRequestCache,
  isInRequestCache,
  memoizedPerRequest,
  reviseInRequestCache,
} from './request-cache'

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

describe('memoizedPerRequest shared in flight', () => {
  // Each call runs as its own request, as the app's requests sent together do.
  const requests = new AsyncLocalStorage<Record<string, unknown>>()
  const inRequest = <T>(call: () => Promise<T>) => requests.run({}, call)

  beforeEach(() => {
    ;(globalThis as unknown as { useEvent: () => unknown }).useEvent = () => {
      const context = requests.getStore()
      if (!context) throw new Error('no request')
      return { context }
    }
  })

  afterEach(() => {
    delete (globalThis as unknown as { useEvent?: unknown }).useEvent
  })

  /** A read that answers when `answer` is called, counting how often it ran. */
  const pendingRead = () => {
    const read = { calls: 0, answer: (_value: string) => {} }
    const run = () => {
      read.calls++
      return new Promise<string>((resolve) => {
        read.answer = resolve
      })
    }
    return { read, run }
  }

  const sharing = { shareInFlight: true }

  test('requests sent together share one read while it is in flight', async () => {
    const { read, run } = pendingRead()
    const first = inRequest(() => memoizedPerRequest('library', run, sharing))
    const second = inRequest(() => memoizedPerRequest('library', run, sharing))
    read.answer('shelf')
    expect(await Promise.all([first, second])).toEqual(['shelf', 'shelf'])
    expect(read.calls).toBe(1)
  })

  test('a read that answered is not kept for the next request', async () => {
    let calls = 0
    const run = async () => `shelf ${++calls}`
    expect(await inRequest(() => memoizedPerRequest('library', run, sharing))).toBe('shelf 1')
    expect(await inRequest(() => memoizedPerRequest('library', run, sharing))).toBe('shelf 2')
  })

  test('a request arriving well after a read started reads on its own', async () => {
    const { read, run } = pendingRead()
    const early = inRequest(() => memoizedPerRequest('library', run, sharing))
    await Bun.sleep(30)
    const late = inRequest(() => memoizedPerRequest('library', async () => 'its own', sharing))
    read.answer('started early')
    expect(await Promise.all([early, late])).toEqual(['started early', 'its own'])
  })

  test('a write forgets the read in flight for the requests after it', async () => {
    const { read, run } = pendingRead()
    const before = inRequest(() => memoizedPerRequest('library', run, sharing))
    await inRequest(async () => evictFromRequestCache('library'))
    const after = inRequest(() => memoizedPerRequest('library', async () => 'fresh', sharing))
    read.answer('stale')
    expect(await Promise.all([before, after])).toEqual(['stale', 'fresh'])
  })

  test('a request that wrote never joins a read started before its write', async () => {
    const { read, run } = pendingRead()
    const before = inRequest(() => memoizedPerRequest('library', run, sharing))
    const writer = inRequest(async () => {
      reviseInRequestCache('library', (shelf: string) => shelf)
      return memoizedPerRequest('library', async () => 'after the write', sharing)
    })
    read.answer('before the write')
    expect(await Promise.all([before, writer])).toEqual(['before the write', 'after the write'])
  })

  test('an evicted key is read again by that request on its own', async () => {
    const { read, run } = pendingRead()
    const other = inRequest(() => memoizedPerRequest('library', run, sharing))
    const writer = inRequest(async () => {
      evictFromRequestCache('library')
      return memoizedPerRequest('library', async () => 'fresh', sharing)
    })
    read.answer('stale')
    expect(await Promise.all([other, writer])).toEqual(['stale', 'fresh'])
    expect(read.calls).toBe(1)
  })

  test('nothing is shared without a request context', async () => {
    delete (globalThis as unknown as { useEvent?: unknown }).useEvent
    let calls = 0
    const run = async () => ++calls
    await Promise.all([
      memoizedPerRequest('library', run, sharing),
      memoizedPerRequest('library', run, sharing),
    ])
    expect(calls).toBe(2)
  })
})
