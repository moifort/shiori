import { describe, expect, test } from 'bun:test'
import { passOverReaders } from './nightly-pass'

const wait = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms))

const options = {
  onFailure: () => {},
  budgetMs: 120_000,
  startedAt: Date.now(),
  concurrency: 4,
}

describe('passOverReaders', () => {
  test('passes over a few readers side by side, never more', async () => {
    let running = 0
    let most = 0
    const run = await passOverReaders(['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'], {
      ...options,
      startedAt: Date.now(),
      syncOne: async () => {
        running += 1
        most = Math.max(most, running)
        await wait(5)
        running -= 1
        return true
      },
    })

    expect(run).toEqual({ synced: 10, failed: 0, deferred: 0 })
    expect(most).toBe(4)
  })

  test('starts the readers in the order given, stalest first', async () => {
    const started: string[] = []
    await passOverReaders(['a', 'b', 'c', 'd', 'e', 'f'], {
      ...options,
      startedAt: Date.now(),
      syncOne: async (reader) => {
        started.push(reader)
        await wait(1)
        return true
      },
    })

    expect(started).toEqual(['a', 'b', 'c', 'd', 'e', 'f'])
  })

  test('steps over a reader whose pass throws and counts nobody to sync apart', async () => {
    const failures: string[] = []
    const run = await passOverReaders(['a', 'b', 'c'], {
      ...options,
      startedAt: Date.now(),
      onFailure: (reader) => {
        failures.push(reader)
      },
      syncOne: async (reader) => {
        if (reader === 'b') throw new Error('device revoked')
        return reader === 'a'
      },
    })

    expect(run).toEqual({ synced: 1, failed: 1, deferred: 0 })
    expect(failures).toEqual(['b'])
  })

  test('starts nobody once the budget is spent, and finishes those already started', async () => {
    const startedAt = Date.now()
    const finished: string[] = []
    const run = await passOverReaders(['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'], {
      ...options,
      budgetMs: 15,
      startedAt,
      syncOne: async (reader) => {
        await wait(30)
        finished.push(reader)
        return true
      },
    })

    expect(run).toEqual({ synced: 4, failed: 0, deferred: 4 })
    expect(finished.sort()).toEqual(['a', 'b', 'c', 'd'])
  })

  test('has nothing to do for no reader', async () => {
    expect(await passOverReaders([], { ...options, syncOne: async () => true })).toEqual({
      synced: 0,
      failed: 0,
      deferred: 0,
    })
  })
})
