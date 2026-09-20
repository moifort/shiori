import { describe, expect, test } from 'bun:test'
import { billedSearches, type GeminiResponse } from '~/domain/scan/gemini'

const answered = (parts: Partial<GeminiResponse>): GeminiResponse => ({
  candidates: [{ content: { parts: [{ text: '{}' }] } }],
  ...parts,
})

describe('counting the searches a call is billed for', () => {
  test('an ungrounded step never searches, whatever the answer carries', () => {
    const response = answered({
      usageMetadata: { billedToolCalls: [{ tool: 'google_search', successfulToolCallCount: 3 }] },
    })

    expect(billedSearches(response, false)).toBe(0)
  })

  test('the billed count is taken when Gemini reports it', () => {
    const response = answered({
      usageMetadata: { billedToolCalls: [{ tool: 'google_search', successfulToolCallCount: 4 }] },
    })

    expect(billedSearches(response, true)).toBe(4)
  })

  test('several billed tools add up', () => {
    const response = answered({
      usageMetadata: {
        billedToolCalls: [
          { tool: 'google_search', successfulToolCallCount: 2 },
          { tool: 'google_search', successfulToolCallCount: 3 },
        ],
      },
    })

    expect(billedSearches(response, true)).toBe(5)
  })

  test('the queries it ran are the fallback when no billed count came back', () => {
    const response = answered({
      candidates: [
        {
          content: { parts: [{ text: '{}' }] },
          groundingMetadata: { webSearchQueries: ['le nom du vent tome', 'kvothe series order'] },
        },
      ],
      usageMetadata: { promptTokenCount: 100 },
    })

    expect(billedSearches(response, true)).toBe(2)
  })

  test('a grounded call that reports nothing counts as one, never as zero', () => {
    // Gemini drops both fields when it searched while thinking. Zero would be
    // the one answer that is certainly wrong, so the floor is one.
    expect(billedSearches(answered({ usageMetadata: { promptTokenCount: 100 } }), true)).toBe(1)
    expect(billedSearches(answered({}), true)).toBe(1)
  })

  test('a reported zero is treated as no report, not as a free grounded call', () => {
    const response = answered({
      usageMetadata: { billedToolCalls: [{ tool: 'google_search', successfulToolCallCount: 0 }] },
      candidates: [
        { content: { parts: [{ text: '{}' }] }, groundingMetadata: { webSearchQueries: [] } },
      ],
    })

    expect(billedSearches(response, true)).toBe(1)
  })
})
