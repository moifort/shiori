import { describe, expect, test } from 'bun:test'
import { suggestionsPrompt } from './prompts'

const profile = {
  formats: [{ value: 'audiobook' as const, share: 0.9 }],
  languages: [{ value: 'fr' as const, share: 1 }],
}

describe('suggestionsPrompt', () => {
  test('asks for French reasons that address the reader, the line starting with "comme"', () => {
    const prompt = suggestionsPrompt('## ♥ Coups de cœur', profile, 'fr')
    expect(prompt).toContain('écrits en français')
    expect(prompt).toContain('qui tutoie le lecteur')
    expect(prompt).toContain('"short": "comme " suivi')
    expect(prompt).toContain('livres audio (90 %)')
  })

  test('asks for English reasons and titles, the line starting with "like"', () => {
    const prompt = suggestionsPrompt('## ♥ Coups de cœur', profile, 'en')
    expect(prompt).toContain('écrits en anglais')
    expect(prompt).toContain("titre de l'édition en anglais")
    expect(prompt).toContain('"short": "like " suivi')
  })
})
