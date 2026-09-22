import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

/** Queued Gemini answers, consumed in call order. Nobody pays Google in a test. */
let answers: unknown[] = []
const calls: string[] = []

// Spread over the real module: a mock is global to the run, and the files that
// test the module's other exports must still find them.
const realGemini = { ...(await import('~/domain/scan/gemini')) }
mock.module('~/domain/scan/gemini', () => ({
  ...realGemini,
  generate: async ({ step }: { step: string }) => {
    calls.push(step)
    const value = answers.shift()
    if (value === undefined) throw new Error(`no queued answer for step "${step}"`)
    if (value instanceof Error) throw value
    return { value, usage: { promptTokens: 10, outputTokens: 5, thinkingTokens: 0, searches: 0 } }
  },
}))

const { SubgenreUseCase } = await import('~/domain/subgenre/use-case')
const { Subgenre } = await import('~/domain/book/primitives')

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
  answers = []
  calls.length = 0
})

const sides = (subgenres: readonly { fr: unknown; en: unknown }[]) =>
  subgenres.map(({ fr, en }) => [String(fr), String(en)])

describe('a subgenre typed by a reader', () => {
  test('is translated once, then found in the dictionary from either side', async () => {
    answers = [
      {
        subgenres: [
          { fr: 'Space Opera', en: 'Space Opera' },
          { fr: 'Jeunesse', en: 'Children' },
        ],
      },
    ]

    const first = await SubgenreUseCase.localized(
      [Subgenre('Space opera'), Subgenre('Jeunesse')],
      'fr',
    )
    expect(sides(first)).toEqual([
      ['Space Opera', 'Space Opera'],
      ['Jeunesse', 'Children'],
    ])
    expect(calls).toEqual(['subgenre-translation'])

    // An English reader typing the other side pays nothing.
    const second = await SubgenreUseCase.localized([Subgenre('children')], 'en')
    expect(sides(second)).toEqual([['Jeunesse', 'Children']])
    expect(calls).toHaveLength(1)
  })

  // The dictionary is read in one round trip, whatever the number of labels.
  test('reads the dictionary in one getAll', async () => {
    fake.seed('subgenre-translations', 'fr-noir', { fr: 'Noir', en: 'Noir' })
    fake.seed('subgenre-translations', 'fr-cosy-mystery', {
      fr: 'Cosy Mystery',
      en: 'Cozy Mystery',
    })
    const before = fake.docReads

    const found = await SubgenreUseCase.localized(
      [Subgenre('Noir'), Subgenre('Cosy mystery')],
      'fr',
    )

    expect(sides(found)).toEqual([
      ['Noir', 'Noir'],
      ['Cosy Mystery', 'Cozy Mystery'],
    ])
    expect(fake.docReads - before).toBe(2)
    expect(calls).toEqual([])
  })

  // The model may respell the reader's word; on their side, their word stays.
  test("keeps the reader's own spelling on their side", async () => {
    answers = [{ subgenres: [{ fr: "Roman d'Aventures", en: 'Adventure Novel' }] }]

    const [subgenre] = await SubgenreUseCase.localized([Subgenre("roman d'aventure")], 'fr')

    expect(sides([subgenre])).toEqual([["Roman d'Aventure", 'Adventure Novel']])
  })

  test('reads the same in every language when the model fails, and is not filed', async () => {
    answers = [new Error('quota exceeded')]

    const [subgenre] = await SubgenreUseCase.localized([Subgenre('Grimdark')], 'en')

    expect(sides([subgenre])).toEqual([['Grimdark', 'Grimdark']])
    expect(fake.snapshot('subgenre-translations').size).toBe(0)
  })

  test('is left untranslated when the answer does not line up with the question', async () => {
    answers = [{ subgenres: [{ fr: 'Noir', en: 'Noir' }] }]

    const found = await SubgenreUseCase.localized([Subgenre('Noir'), Subgenre('Polar')], 'fr')

    expect(sides(found)).toEqual([
      ['Noir', 'Noir'],
      ['Polar', 'Polar'],
    ])
  })
})
