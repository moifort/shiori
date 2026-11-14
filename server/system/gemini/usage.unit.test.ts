import { describe, expect, test } from 'bun:test'
import { freeSearchesSpent, summedUsage } from '~/system/gemini/usage'

describe("when Gemini's free searches are spent", () => {
  // 6.3 searches a call: 714 calls is 4,498 searches, 715 is 4,504.
  test('not before the margin under the 5,000 free', () => {
    expect(freeSearchesSpent(0)).toBe(false)
    expect(freeSearchesSpent(714)).toBe(false)
  })

  test('from the margin on, and for the rest of the month', () => {
    expect(freeSearchesSpent(715)).toBe(true)
    expect(freeSearchesSpent(2000)).toBe(true)
  })
})

describe('summedUsage', () => {
  const usage = { promptTokens: 10, outputTokens: 5, thinkingTokens: 2, searches: 1 }

  test('adds two calls made for one step', () => {
    expect(summedUsage(usage, usage)).toEqual({
      promptTokens: 20,
      outputTokens: 10,
      thinkingTokens: 4,
      searches: 2,
    })
  })

  test('keeps the one call that reported its usage', () => {
    expect(summedUsage(usage, undefined)).toEqual(usage)
    expect(summedUsage(undefined, usage)).toEqual(usage)
    expect(summedUsage(undefined, undefined)).toBeUndefined()
  })
})
