import { describe, expect, test } from 'bun:test'
import { suggestionsOf } from './parsing'

const item = (extra: Record<string, unknown> = {}) => ({
  title: 'Les Salauds Gentilshommes',
  originalTitle: 'The Lies of Locke Lamora',
  author: 'Scott Lynch',
  language: 'en',
  kind: 'novel',
  reason: 'Un héros rusé, comme dans Gagner la guerre.',
  short: 'comme Gagner la guerre',
  references: ['Gagner la guerre'],
  ...extra,
})

describe('suggestionsOf', () => {
  test('reads the array out of the text around it', () => {
    const [suggestion] = suggestionsOf(`Voici :\n${JSON.stringify([item()])}\nBonne lecture`)
    expect(suggestion).toEqual({
      key: 'lies-of-locke-lamora--scott-lynch',
      title: 'Les Salauds Gentilshommes',
      originalTitle: 'The Lies of Locke Lamora',
      authors: ['Scott Lynch'],
      language: 'en',
      kind: 'novel',
      reason: 'Un héros rusé, comme dans Gagner la guerre.',
      short: 'comme Gagner la guerre',
      references: ['Gagner la guerre'],
    } as never)
  })

  test('splits several authors and falls back on the title, English and a novel', () => {
    const [suggestion] = suggestionsOf(
      JSON.stringify([
        item({
          originalTitle: undefined,
          author: 'Naomi Oreskes, Erik M. Conway',
          language: 'xx',
          kind: 'poem',
        }),
      ]),
    )
    expect(suggestion?.authors).toEqual(['Naomi Oreskes', 'Erik M. Conway'] as never)
    expect(suggestion?.originalTitle).toBe('Les Salauds Gentilshommes' as never)
    expect(suggestion?.language).toBe('en')
    expect(suggestion?.kind).toBe('novel')
  })

  test('leaves out an item with no reason, and a book named twice', () => {
    const suggestions = suggestionsOf(
      JSON.stringify([item(), item({ reason: '' }), item({ title: 'Autre titre' })]),
    )
    expect(suggestions).toHaveLength(1)
  })

  test('throws on an answer with no array', () => {
    expect(() => suggestionsOf('Je ne peux pas.')).toThrow('no JSON array')
  })
})
