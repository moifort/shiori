import { describe, expect, test } from 'bun:test'
import { cleanedTitleOf } from '~/domain/scan/page-title'

const page = (title: string) => `<html><head><title>${title}</title></head><body>…</body></html>`

describe('cleanedTitleOf', () => {
  // What a bookshop actually puts in its title bar.
  test('keeps the work and drops the shop around it', () => {
    expect(cleanedTitleOf(page('Amazon.fr - Le Nom du vent - Rothfuss, Patrick - Livres'))).toBe(
      'Le Nom du vent',
    )
    expect(cleanedTitleOf(page('Dune | Fnac'))).toBe('Dune')
    expect(cleanedTitleOf(page('Hypérion — Babelio'))).toBe('Hypérion')
  })

  test('decodes what the markup escaped', () => {
    expect(cleanedTitleOf(page('L&#39;Assassin royal &amp; ses suites'))).toBe(
      "L'Assassin royal & ses suites",
    )
  })

  test('keeps a title that has nothing around it', () => {
    expect(cleanedTitleOf(page('Le Problème à trois corps'))).toBe('Le Problème à trois corps')
  })

  test('folds the whitespace a template left behind', () => {
    expect(cleanedTitleOf('<title>\n   Dune\n\n  </title>')).toBe('Dune')
  })

  // A page with nothing to read is a lookup that falls back, not a failure.
  test('answers nothing for a page with no title', () => {
    expect(cleanedTitleOf('<html><body>Bonjour</body></html>')).toBeUndefined()
    expect(cleanedTitleOf(page('   '))).toBeUndefined()
  })
})
