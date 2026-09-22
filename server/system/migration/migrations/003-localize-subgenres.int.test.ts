import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

let answers: unknown[] = []
const prompts: string[] = []

// Spread over the real module: a mock is global to the run, and the files that
// test the module's other exports must still find them.
const realGemini = { ...(await import('~/domain/scan/gemini')) }
mock.module('~/domain/scan/gemini', () => ({
  ...realGemini,
  generate: async ({ parts }: { parts: { text?: string }[] }) => {
    prompts.push(parts.map((part) => part.text ?? '').join(''))
    const value = answers.shift()
    if (value === undefined) throw new Error('no queued answer')
    if (value instanceof Error) throw value
    return { value }
  },
}))

const { localizeSubgenres } = await import('~/system/migration/migrations/003-localize-subgenres')

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
  answers = []
  prompts.length = 0
})

const subgenresOf = (id: string) => fake.data('books', id)?.subgenres

describe('localizing the stored subgenres', () => {
  test('translates every distinct label once and rewrites every book', async () => {
    fake.seed('subgenre-translations', 'en-young-adult', { fr: 'Young Adult', en: 'Young Adult' })
    fake.seed('books', 'a', { userId: 'r', subgenres: ['Dark Fantasy', 'Young Adult'] })
    fake.seed('books', 'b', { userId: 'r', subgenres: ['dark fantasy', 'Jeunesse'] })
    fake.seed('books', 'c', { userId: 'r', subgenres: [] })
    answers = [
      {
        subgenres: [
          { fr: 'Dark Fantasy', en: 'Dark Fantasy' },
          { fr: 'Jeunesse', en: 'Children' },
        ],
      },
    ]

    expect(await localizeSubgenres.migrate({ db: fakeDb() as never })).toEqual({
      ok: true,
      transformed: 2,
    })
    expect(prompts).toHaveLength(1)
    expect(prompts[0]).not.toContain('Young Adult')
    expect(subgenresOf('a')).toEqual([
      { fr: 'Dark Fantasy', en: 'Dark Fantasy' },
      { fr: 'Young Adult', en: 'Young Adult' },
    ])
    expect(subgenresOf('b')).toEqual([
      { fr: 'Dark Fantasy', en: 'Dark Fantasy' },
      { fr: 'Jeunesse', en: 'Children' },
    ])
    expect(subgenresOf('c')).toEqual([])
    expect(fake.data('subgenre-translations', 'en-children')).toEqual({
      fr: 'Jeunesse',
      en: 'Children',
    })
  })

  test('rewrites nothing when the model fails, so a second run starts clean', async () => {
    fake.seed('books', 'a', { userId: 'r', subgenres: ['Grimdark'] })
    answers = [new Error('quota exceeded')]

    await expect(localizeSubgenres.migrate({ db: fakeDb() as never })).rejects.toThrow(
      'quota exceeded',
    )
    expect(subgenresOf('a')).toEqual(['Grimdark'])
  })

  test('leaves a book already localized alone', async () => {
    fake.seed('books', 'a', { userId: 'r', subgenres: [{ fr: 'Noir', en: 'Noir' }] })

    expect(await localizeSubgenres.migrate({ db: fakeDb() as never })).toEqual({
      ok: true,
      transformed: 0,
    })
    expect(prompts).toEqual([])
  })
})
