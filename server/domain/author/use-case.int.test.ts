import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

/** Queued Gemini answers, consumed in call order: nobody pays Google in a test. */
let answers: unknown[] = []
const calls: string[] = []
mock.module('~/domain/scan/gemini', () => ({
  generate: async ({ step }: { step: string }) => {
    calls.push(step)
    const value = answers.shift()
    if (value === undefined) throw new Error(`no queued answer for step "${step}"`)
    return { value, usage: { promptTokens: 10, outputTokens: 5, thinkingTokens: 20, searches: 1 } }
  },
}))
mock.module('~/domain/author/infrastructure/wikipedia', () => ({
  portraitOf: async (title: string) => `https://upload.wikimedia.org/${title}.jpg`,
}))

const { AuthorUseCase } = await import('~/domain/author/use-case')
const { authorKeyOf } = await import('~/domain/author/primitives')
const { BookCommand } = await import('~/domain/book/command')
const { SeriesOpinionCommand } = await import('~/domain/series-opinion/command')
const { SeriesId, SeriesName, VolumeNumber } = await import('~/domain/series/primitives')
const { AuthorName, BookTitle } = await import('~/domain/shared/primitives')

const reader = 'reader-1' as UserId

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
  answers = []
  calls.length = 0
})

/** One author per saga, each saga catalogued with three volumes. */
const writeSagas = async (count: number) => {
  for (let index = 0; index < count; index++) {
    const id = SeriesId(`saga-${index}`)
    fake.seed('series', id, {
      id,
      name: `Saga ${index}`,
      author: `Author ${index}`,
      volumes: [1, 2, 3].map((number) => ({ number, title: `Tome ${number}`, kind: 'main' })),
    })
    await BookCommand.add(reader, {
      title: BookTitle(`Saga ${index}, tome 1`),
      authors: [AuthorName(`Author ${index}`)],
      status: 'read',
      series: { id, name: SeriesName(`Saga ${index}`), volume: VolumeNumber(1), kind: 'main' },
    })
  }
}

describe('a page of the Authors tab', () => {
  // The library and the opinions are one scan each; the page's own author
  // catalogues are read in one getAll, for their portraits, and no saga's.
  test('reads the library, the opinions and the page’s author catalogues', async () => {
    await writeSagas(12)
    const docReads = fake.docReads
    const queryReads = fake.queryReads

    const { items, hasMore } = await AuthorUseCase.followedPage(reader, { limit: 5, offset: 0 }, {})

    expect(items).toHaveLength(5)
    expect(hasMore).toBe(true)
    expect(fake.docReads - docReads).toBe(5)
    expect(fake.queryReads - queryReads).toBe(2)
  })

  test('puts the author the reader loves first', async () => {
    await writeSagas(3)
    await SeriesOpinionCommand.setFavorite(reader, SeriesId('saga-2'), true)

    const { items } = await AuthorUseCase.followedPage(reader, { limit: 10, offset: 0 }, {})

    expect(items[0]?.name).toBe(AuthorName('Author 2'))
    expect(Number(items[0]?.favoriteCount)).toBe(1)
  })

  test('keeps only the authors with a heart in the favourites', async () => {
    await writeSagas(3)
    await SeriesOpinionCommand.setFavorite(reader, SeriesId('saga-1'), true)

    const { items, hasMore } = await AuthorUseCase.followedPage(
      reader,
      { limit: 10, offset: 0 },
      { favorite: true },
    )

    expect(items.map((author) => String(author.name))).toEqual(['Author 1'])
    expect(hasMore).toBe(false)
  })

  test('answers the same rows as a whole list, cut to the page', async () => {
    await writeSagas(4)

    const whole = await AuthorUseCase.followedPage(reader, { limit: 10, offset: 0 }, {})
    const second = await AuthorUseCase.followedPage(reader, { limit: 2, offset: 2 }, {})

    expect(second.items.map((author) => author.key)).toEqual(
      whole.items.slice(2, 4).map((author) => author.key),
    )
    expect(second.hasMore).toBe(false)
  })
})

const sanderson = {
  name: 'Brandon Sanderson',
  nationality: 'Américain',
  birthYear: 1975,
  deathYear: null,
  biography: 'Auteur de fantasy.',
  wikipediaTitle: 'Brandon Sanderson',
  series: [
    { name: 'Saga 0', volumeCount: 3, firstVolumeTitle: 'Tome 1' },
    { name: 'Skyward', volumeCount: 4, firstVolumeTitle: 'Skyward' },
  ],
  books: [
    { title: 'Elantris', publishedIn: 2005 },
    { title: 'Warbreaker', publishedIn: 2009 },
  ],
}

describe('an author’s page', () => {
  const holdSanderson = async () => {
    const id = SeriesId('saga-0--brandon-sanderson')
    await BookCommand.add(reader, {
      title: BookTitle('Tome 1'),
      authors: [AuthorName('Brandon Sanderson')],
      status: 'read',
      series: { id, name: SeriesName('Saga 0'), volume: VolumeNumber(1), kind: 'main' },
    })
    await BookCommand.add(reader, {
      title: BookTitle('Elantris'),
      authors: [AuthorName('Brandon Sanderson')],
    })
  }

  test('is built on the first opening, portrait included, and read after', async () => {
    await holdSanderson()
    answers = [sanderson]

    const first = await AuthorUseCase.page(reader, authorKeyOf('Brandon Sanderson'), 'fr')
    const second = await AuthorUseCase.page(reader, authorKeyOf('Brandon Sanderson'), 'fr')

    expect(calls).toEqual(['author'])
    expect(String(first?.catalogue?.portraitUrl)).toBe(
      'https://upload.wikimedia.org/Brandon Sanderson.jpg',
    )
    expect(second?.catalogue?.biography).toBe(first?.catalogue?.biography)
    expect(String(second?.author.portraitUrl)).toBe(String(first?.catalogue?.portraitUrl))
  })

  test('sets what the reader holds apart from what they could add', async () => {
    await holdSanderson()
    answers = [sanderson]

    const page = await AuthorUseCase.page(reader, authorKeyOf('Brandon Sanderson'), 'fr')

    expect(page?.sagas.map((saga) => String(saga.name))).toEqual(['Saga 0'])
    expect(page?.catalogue?.series.map((saga) => String(saga.name))).toEqual(['Saga 0', 'Skyward'])
    expect(page?.books.map((book) => String(book.title))).toEqual(['Elantris'])
    expect(page?.booksNotHeld.map((work) => String(work.title))).toEqual(['Warbreaker'])
  })

  // The defect: an author the model found nothing on made every opening of
  // their page wait on the same grounded call. Now it is asked once, and only
  // the reader's refresh asks again.
  test('still shows the reader’s books when the model found nothing, and does not ask again', async () => {
    await holdSanderson()
    answers = [{ name: 'Brandon Sanderson', series: [], books: [] }]

    const failed = await AuthorUseCase.page(reader, authorKeyOf('Brandon Sanderson'), 'fr')
    const reopened = await AuthorUseCase.page(reader, authorKeyOf('Brandon Sanderson'), 'fr')

    expect(failed?.catalogue).toBeNull()
    expect(failed?.books).toHaveLength(1)
    expect(reopened?.catalogue).toBeNull()
    expect(calls).toEqual(['author'])
  })

  // The defect: Isaac Asimov's page came back with a biography and no book at
  // all, was stored as known, and never showed more than the reader's shelf.
  test('stores no catalogue whose bibliography came back empty, biography or not', async () => {
    await holdSanderson()
    answers = [{ ...sanderson, series: [], books: [] }]

    const page = await AuthorUseCase.page(reader, authorKeyOf('Brandon Sanderson'), 'fr')

    expect(page?.catalogue).toBeNull()
    expect(fake.snapshot('authors').size).toBe(0)
  })

  test('does not ask again after a failed call either', async () => {
    await holdSanderson()

    await AuthorUseCase.page(reader, authorKeyOf('Brandon Sanderson'), 'fr')
    await AuthorUseCase.page(reader, authorKeyOf('Brandon Sanderson'), 'fr')

    expect(calls).toEqual(['author'])
  })

  test('is built again when the reader asks, after the model found nothing', async () => {
    await holdSanderson()
    answers = [{ name: 'Brandon Sanderson', series: [], books: [] }, sanderson]
    await AuthorUseCase.page(reader, authorKeyOf('Brandon Sanderson'), 'fr')

    const refreshed = await AuthorUseCase.recatalogue(
      reader,
      authorKeyOf('Brandon Sanderson'),
      'fr',
    )
    const page = await AuthorUseCase.page(reader, authorKeyOf('Brandon Sanderson'), 'fr')

    expect(refreshed?.biography).toBeDefined()
    expect(page?.catalogue?.biography).toBe(refreshed?.biography)
    expect(calls).toEqual(['author', 'author'])
  })

  test('keeps the stored catalogue when a refresh finds nothing', async () => {
    await holdSanderson()
    answers = [sanderson, { name: 'Brandon Sanderson', series: [], books: [] }]
    const built = await AuthorUseCase.page(reader, authorKeyOf('Brandon Sanderson'), 'fr')

    const refreshed = await AuthorUseCase.recatalogue(
      reader,
      authorKeyOf('Brandon Sanderson'),
      'fr',
    )
    const page = await AuthorUseCase.page(reader, authorKeyOf('Brandon Sanderson'), 'fr')

    expect(refreshed).toBeNull()
    expect(page?.catalogue?.biography).toBe(built?.catalogue?.biography)
  })

  test('refreshes nothing for an author the reader holds no book of', async () => {
    expect(await AuthorUseCase.recatalogue(reader, authorKeyOf('Nobody'), 'fr')).toBeNull()
    expect(calls).toEqual([])
  })

  test('answers nothing for an author the reader holds no book of', async () => {
    expect(await AuthorUseCase.page(reader, authorKeyOf('Nobody'), 'fr')).toBeNull()
    expect(calls).toEqual([])
  })
})
