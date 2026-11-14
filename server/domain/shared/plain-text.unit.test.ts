import { describe, expect, test } from 'bun:test'
import { plainTextOf } from '~/domain/shared/plain-text'

describe('plainTextOf', () => {
  test('keeps the paragraphs and line breaks, drops the markup, decodes the entities', () => {
    expect(
      plainTextOf('<p>Un&nbsp;récit.<br/>Deux</p><p>L&#39;autre &amp; &quot;lui&quot;</p>'),
    ).toBe('Un récit.\nDeux\n\nL\'autre & "lui"')
  })

  test('caps a long text at 4000 characters', () => {
    expect(plainTextOf('a'.repeat(5000))).toHaveLength(4000)
  })

  test('answers nothing for nothing', () => {
    expect(plainTextOf(undefined)).toBeUndefined()
    expect(plainTextOf('')).toBeUndefined()
  })
})
