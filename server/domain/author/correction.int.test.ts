import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

/** Queued Gemini answers: nobody pays Google in a test. */
let answers: unknown[] = []
mock.module('~/domain/scan/gemini', () => ({
  generate: async () => {
    const value = answers.shift()
    if (value === undefined) throw new Error('no queued answer')
    return { value, usage: { promptTokens: 1, outputTokens: 1, thinkingTokens: 1, searches: 1 } }
  },
}))
mock.module('~/domain/scan/open-library', () => ({
  openLibraryIsbnsOf: async () => [],
  openLibraryCoverOf: async () => undefined,
  openLibraryCoverByTitle: async () => undefined,
}))
mock.module('~/domain/author/infrastructure/wikipedia', () => ({
  portraitOf: async () => 'https://upload.wikimedia.org/wikipedia.jpg',
}))
mock.module('~/domain/author/infrastructure/wikidata', () => ({
  wikidataPortraitOf: async () => 'https://upload.wikimedia.org/wikidata.jpg',
}))
mock.module('~/domain/author/infrastructure/open-library', () => ({
  openLibraryPortraitOf: async () => 'https://upload.wikimedia.org/wikipedia.jpg',
}))
/** The addresses that serve no image. */
const notImages = new Set<string>()
const publishedCover = await import('~/domain/scan/published-cover')
mock.module('~/domain/scan/published-cover', () => ({
  ...publishedCover,
  isImageAt: async (url: string) => !notImages.has(url),
}))

const { AuthorUseCase } = await import('~/domain/author/use-case')
const { AuthorCommand } = await import('~/domain/author/command')
const { AuthorQuery } = await import('~/domain/author/query')
const { authorKeyOf, AuthorBiography, PortraitUrl } = await import('~/domain/author/primitives')
const { BookCommand } = await import('~/domain/book/command')
const { CatalogueCorrectionQuery } = await import('~/domain/catalogue-correction/query')
const { AuthorName, BookTitle, Year } = await import('~/domain/shared/primitives')

const reader = 'reader-1' as UserId
const name = AuthorName('Brandon Sanderson')
const key = authorKeyOf(name)

const sanderson = {
  name: 'Brandon Sanderson',
  nationality: 'Américain',
  birthYear: 1975,
  deathYear: null,
  biography: 'Auteur de science-fiction.',
  wikipediaTitle: 'Brandon Sanderson',
  series: [],
  books: [{ title: 'Elantris', publishedIn: 2005 }],
}

beforeEach(async () => {
  resetFakeFirestore()
  answers = []
  notImages.clear()
  await BookCommand.add(reader, { title: BookTitle('Elantris'), authors: [name] })
})

describe('correcting an author', () => {
  test('writes into the shared catalogue, logged under the reader’s name', async () => {
    answers = [sanderson]
    await AuthorCommand.catalogueFromWeb(key, name, 'fr')

    const page = await AuthorUseCase.correct(reader, key, 'fr', {
      biography: AuthorBiography('Auteur de fantasy.'),
      deathYear: undefined,
      birthYear: Year(1975),
    })

    expect(page).toMatchObject({ catalogue: { biography: 'Auteur de fantasy.', birthYear: 1975 } })
    const stored = await AuthorQuery.byKey(key)
    expect(stored?.corrected).toEqual(['birthYear', 'deathYear', 'biography'])
    expect(stored?.books).toHaveLength(1)
    expect(await CatalogueCorrectionQuery.byUser(reader)).toMatchObject([
      {
        catalogue: 'author',
        documentId: key,
        field: 'biography',
        before: 'Auteur de science-fiction.',
      },
    ])
  })

  test('keeps the corrections when the catalogue is asked again', async () => {
    answers = [sanderson]
    await AuthorCommand.catalogueFromWeb(key, name, 'fr')
    await AuthorUseCase.correct(reader, key, 'fr', {
      biography: AuthorBiography('Auteur de fantasy.'),
      nationality: undefined,
      portraitUrl: PortraitUrl('https://example.com/sanderson.jpg'),
    })

    answers = [sanderson]
    const { author } = await AuthorCommand.catalogueFromWeb(key, name, 'fr')

    expect(author?.biography).toBe(AuthorBiography('Auteur de fantasy.'))
    expect(author?.nationality).toBeUndefined()
    expect(author?.portraitUrl).toBe(PortraitUrl('https://example.com/sanderson.jpg'))
    expect(author?.birthYear).toBe(Year(1975))
  })

  test('gives an author nobody could describe a catalogue of the correction alone', async () => {
    await AuthorCommand.catalogueFromWeb(key, name, 'fr')
    expect(await AuthorQuery.byKey(key)).toBeNull()

    await AuthorUseCase.correct(reader, key, 'fr', {
      portraitUrl: PortraitUrl('https://example.com/sanderson.jpg'),
    })

    expect(await AuthorQuery.byKey(key)).toMatchObject({
      name: 'Brandon Sanderson',
      portraitUrl: 'https://example.com/sanderson.jpg',
      series: [],
      books: [],
    })
  })

  test('refuses an address that serves no image', async () => {
    notImages.add('https://example.com/page')

    expect(
      await AuthorUseCase.correct(reader, key, 'fr', {
        portraitUrl: PortraitUrl('https://example.com/page'),
      }),
    ).toBe('not-an-image')
    expect(await AuthorQuery.byKey(key)).toBeNull()
  })

  test('is not found for an author the reader holds nothing of', async () => {
    expect(
      await AuthorUseCase.correct(reader, authorKeyOf('Robin Hobb'), 'fr', {
        biography: AuthorBiography('Autrice.'),
      }),
    ).toBeNull()
  })
})

describe('the portraits offered for an author', () => {
  test('lists the current one first, then each other face once', async () => {
    answers = [sanderson]
    await AuthorCommand.catalogueFromWeb(key, name, 'fr')

    expect(await AuthorUseCase.portraitChoices(reader, key)).toEqual([
      {
        source: 'wikipedia',
        url: PortraitUrl('https://upload.wikimedia.org/wikipedia.jpg'),
        isCurrent: true,
      },
      {
        source: 'wikidata',
        url: PortraitUrl('https://upload.wikimedia.org/wikidata.jpg'),
        isCurrent: false,
      },
    ])
  })

  test('keeps a pasted portrait at the head', async () => {
    answers = [sanderson]
    await AuthorCommand.catalogueFromWeb(key, name, 'fr')
    await AuthorUseCase.correct(reader, key, 'fr', {
      portraitUrl: PortraitUrl('https://example.com/sanderson.jpg'),
    })

    expect((await AuthorUseCase.portraitChoices(reader, key))?.[0]).toEqual({
      source: 'web',
      url: PortraitUrl('https://example.com/sanderson.jpg'),
      isCurrent: true,
    })
  })
})
