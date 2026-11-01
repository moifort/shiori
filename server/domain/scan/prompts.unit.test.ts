import { describe, expect, test } from 'bun:test'
import { BookTitle } from '~/domain/book/primitives'
import { enrichmentPrompt } from '~/domain/scan/prompts'

describe('enrichmentPrompt', () => {
  const named = {
    title: BookTitle('Le mensonge'),
    authors: ['Carole Martinez'],
  } as Parameters<typeof enrichmentPrompt>[0]

  // On 2026-10-25 a reader typed a title no book of that author carries, and
  // the model, told only to fill the record, explained in prose that it could
  // not: an answer with no JSON in it fails the step and bills a second search.
  test('says what to answer when no book matches, typed or scanned', () => {
    for (const source of ['typed', 'cover'] as const) {
      const prompt = enrichmentPrompt(named, 'fr', source)
      expect(prompt).toContain('Si la recherche ne trouve aucun livre qui corresponde')
      expect(prompt).toContain("réponds quand même par l'objet JSON")
    }
  })
})
