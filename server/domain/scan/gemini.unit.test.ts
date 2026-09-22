import { describe, expect, test } from 'bun:test'
import { answerOf, billedSearches, type GeminiResponse, requestBodyOf } from '~/domain/scan/gemini'

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

describe('asking for JSON', () => {
  const schema = { type: 'object', properties: { name: { type: 'string' } } }

  test('an ungrounded step uses the API JSON mode, with its schema', () => {
    const body = requestBodyOf({
      step: 'vision',
      parts: [{ text: 'Lis.' }],
      responseSchema: schema,
    })

    expect(body.generationConfig).toEqual({
      responseMimeType: 'application/json',
      responseSchema: schema,
    })
    expect(body.tools).toBeUndefined()
    expect(body.contents[0].parts).toEqual([{ text: 'Lis.' }])
  })

  test('a grounded step asks for its JSON in words, since the API JSON mode answers empty', () => {
    const body = requestBodyOf({
      step: 'catalogue',
      parts: [{ text: 'Cherche.' }],
      responseSchema: schema,
      grounded: true,
    })

    expect(body.generationConfig).toBeUndefined()
    expect(body.tools).toEqual([{ google_search: {} }])
    const [prompt, shape] = body.contents[0].parts
    expect(prompt).toEqual({ text: 'Cherche.' })
    expect(shape).toHaveProperty('text', expect.stringContaining(JSON.stringify(schema)))
  })
})

describe('reading the answer', () => {
  test('a bare JSON object is read as it is', () => {
    expect(answerOf('{"name":"Heretical Fishing"}')).toEqual({ name: 'Heretical Fishing' })
  })

  test('a fenced object is read out of its fence', () => {
    expect(answerOf('```json\n{"name":"Heretical Fishing"}\n```')).toEqual({
      name: 'Heretical Fishing',
    })
  })

  test('words around the object are ignored', () => {
    expect(answerOf('Voici le catalogue :\n{"volumes":[{"title":"Un"}]}\nBonne lecture.')).toEqual({
      volumes: [{ title: 'Un' }],
    })
  })

  test('an answer with no object is an error, not an empty value', () => {
    expect(() => answerOf('Je ne trouve pas cette série.')).toThrow()
  })
})
