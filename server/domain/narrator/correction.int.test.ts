import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

/** Queued Gemini answers: nobody pays Google in a test. */
let answers: unknown[] = []
mock.module('~/system/gemini', () => ({
  generate: async () => {
    const value = answers.shift()
    if (value === undefined) throw new Error('no queued answer')
    return { value, usage: { promptTokens: 1, outputTokens: 1, thinkingTokens: 1, searches: 1 } }
  },
}))
mock.module('~/domain/author/infrastructure/wikipedia', () => ({
  portraitOf: async () => 'https://upload.wikimedia.org/face.jpg',
}))

const { NarratorCommand } = await import('~/domain/narrator/command')
const { NarratorQuery } = await import('~/domain/narrator/query')
const { narratorKeyOf, NarratorBiography } = await import('~/domain/narrator/primitives')
const { NarratorName } = await import('~/domain/book/primitives')

const name = NarratorName('Kobna Holdbrook-Smith')
const key = narratorKeyOf(name)

const described = {
  name: 'Kobna Holdbrook-Smith',
  nationality: 'Britannique',
  birthYear: 1977,
  deathYear: null,
  biography: 'Comédien et lecteur.',
  wikipediaTitle: 'Kobna Holdbrook-Smith',
}

beforeEach(() => {
  resetFakeFirestore()
  answers = []
})

// A page's catalogue call takes seconds, and a reader may correct the narrator
// meanwhile: each writer builds on the entry as it stands when it writes.
describe('writers of one narrator crossing', () => {
  test('a catalogue call keeps a correction made since the page read the narrator', async () => {
    const known = await NarratorQuery.byKey(key)
    await NarratorCommand.correct(undefined, key, name, {
      biography: NarratorBiography('Corrigée.'),
    })
    answers = [described]

    await NarratorCommand.catalogueFromWeb(known, key, name, 'fr')

    expect(String((await NarratorQuery.byKey(key))?.biography)).toBe('Corrigée.')
  })

  test('a portrait lookup keeps a correction made since the page read the narrator', async () => {
    answers = [described]
    const { narrator } = await NarratorCommand.catalogueFromWeb(undefined, key, name, 'fr')
    const stale = { ...narrator, portraitUrl: undefined }
    await NarratorCommand.correct(narrator, key, name, {
      biography: NarratorBiography('Corrigée.'),
    })

    await NarratorCommand.seekPortrait(stale)

    expect(String((await NarratorQuery.byKey(key))?.biography)).toBe('Corrigée.')
  })
})
