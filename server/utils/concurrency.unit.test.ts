import { describe, expect, test } from 'bun:test'
import { eachWithAtMostInFlight } from '~/utils/concurrency'

describe('eachWithAtMostInFlight', () => {
  test('never has more than the limit in flight, and reaches every item', async () => {
    let inFlight = 0
    let most = 0
    const done: number[] = []

    await eachWithAtMostInFlight(
      Array.from({ length: 20 }, (_, index) => index),
      3,
      async (item) => {
        inFlight += 1
        most = Math.max(most, inFlight)
        await Bun.sleep(1)
        done.push(item)
        inFlight -= 1
      },
    )

    expect(most).toBe(3)
    expect(done.sort((a, b) => a - b)).toEqual(Array.from({ length: 20 }, (_, index) => index))
  })

  test('does nothing for no item', async () => {
    let calls = 0
    await eachWithAtMostInFlight([], 3, async () => {
      calls += 1
    })
    expect(calls).toBe(0)
  })
})
