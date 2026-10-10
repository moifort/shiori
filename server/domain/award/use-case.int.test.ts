import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { Genre } from '~/domain/book/types'
import type { UserId } from '~/domain/shared/types'
import {
  type FakeFirestore,
  fakeDb,
  resetFakeFirestore,
  startFakeRequest,
} from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

/** Stands in for Gemini: nothing here may ask it anything. */
const asked: string[] = []
mock.module('~/domain/scan/gemini', () => ({
  generate: async ({ step }: { step: string }) => {
    asked.push(step)
    return {
      usage: { promptTokens: 1, outputTokens: 1, thinkingTokens: 0, searches: 1 },
      value: { found: false },
    }
  },
}))

/** Stands in for Wikidata: the winners it records of each award, and every
 *  award and year it was asked after. */
const wikidataAsked: string[] = []
let wikidata: Record<string, { year: number; title: string; authors: string[] }[] | 'down'> = {}
mock.module('~/domain/award/infrastructure/wikidata', () => ({
  winnersAfter: async (award: string, after: number) => {
    wikidataAsked.push(`${award}>${after}`)
    const known = wikidata[award] ?? []
    if (known === 'down') throw new Error('Wikidata answered 503')
    return known.filter(({ year }) => year > after)
  },
}))
mock.module('~/domain/discovery/infrastructure/amazon-catalogue', () => ({
  amazonEditionOf: async () => ({ releaseDate: '1991-06-01' }),
}))
mock.module('~/domain/scan/published-cover', () => ({
  publishedCoverOf: async () => 'https://covers.example/hyperion.jpg',
  isCoverGone: async () => false,
}))

const { AwardUseCase } = await import('~/domain/award/use-case')
const { AwaitedEditionUseCase } = await import('~/domain/awaited-edition/use-case')
const { AuthorName, BookTitle } = await import('~/domain/shared/primitives')
const { watchKeyOf } = await import('~/domain/award/business-rules')
const { releaseDescriptionKeyOf } = await import('~/domain/discovery/business-rules')

const reader = 'reader' as UserId
const now = new Date('2026-10-08T08:00:00Z')
let fake: FakeFirestore
let shelved = 0

const shelve = (
  title: string,
  author: string,
  genre: Genre,
  status: 'read' | 'to-read' = 'read',
  format: 'book' | 'audiobook' = 'book',
) => {
  shelved += 1
  fake.seed('books', `book-${shelved}`, {
    id: `book-${shelved}`,
    userId: reader,
    title,
    authors: [author],
    format,
    media: format === 'book' ? ['print'] : [],
    genre,
    subgenres: [],
    narrators: [],
    language: 'fr',
    status,
    hidden: false,
    addedAt: now,
  })
}

/** A science fiction reader: three novels read, none of them crowned lately. */
const sfReader = () => {
  shelve('Les Cantos d’Hypérion', 'Dan Simmons', 'science-fiction')
  shelve('Fondation', 'Isaac Asimov', 'science-fiction')
  shelve('La Stratégie Ender', 'Orson Scott Card', 'science-fiction')
}

const deathOfTheAuthor = {
  title: BookTitle('Death of the Author'),
  authors: [AuthorName('Nnedi Okorafor')],
}

/** What the web found of Death of the Author in French, as the awaited
 *  editions' pass kept it once a reader awaited it. */
const deathOfTheAuthorFound = () => {
  const key = watchKeyOf(deathOfTheAuthor, 'book', 'fr')
  fake.seed('edition-watches', key, {
    key,
    title: 'Death of the Author',
    author: 'Nnedi Okorafor',
    originalLanguage: 'en',
    format: 'book',
    language: 'fr',
    checkedAt: now,
    found: { title: 'La Mort de l’auteur', date: '2026-03-01' },
  })
}

beforeEach(() => {
  fake = resetFakeFirestore()
  asked.length = 0
  wikidataAsked.length = 0
  wikidata = {}
  shelved = 0
})

describe('the award shelf', () => {
  test('is the latest ceremony of each award of the genre the reader reads most', async () => {
    sfReader()
    const shelf = await AwardUseCase.shelf(reader, 'book', 'fr', undefined, now)

    expect(shelf?.genre).toBe('science-fiction')
    expect(shelf?.awards.map((list) => list.award)).toEqual([
      'hugo',
      'nebula',
      'locus-sf',
      'clarke',
    ])
    expect(shelf?.recent.map((view) => view.work.title)).toEqual([
      BookTitle('The Everlasting'),
      BookTitle('The Buffalo Hunter Hunter'),
      BookTitle('Death of the Author'),
      BookTitle('Annie Bot'),
    ])
    expect(asked).toEqual([])
  })

  test('draws a winner with no cover found with the one its page found when described', async () => {
    sfReader()
    const key = releaseDescriptionKeyOf(
      {
        title: BookTitle('The Everlasting'),
        authors: [AuthorName('Alix E. Harrow')],
        format: 'book',
        language: 'en',
      },
      'fr',
    )
    fake.seed('release-descriptions', key, {
      key,
      description: {
        book: { title: 'The Everlasting', coverUrl: 'https://covers.example/everlasting.jpg' },
        narrators: [],
      },
      describedAt: now,
    })

    const shelf = await AwardUseCase.shelf(reader, 'book', 'fr', undefined, now)

    expect(shelf?.recent[0]?.describedCoverUrl).toBe(
      'https://covers.example/everlasting.jpg' as never,
    )
    expect(shelf?.recent[1]?.describedCoverUrl).toBeUndefined()
  })

  test('is absent for a reader of no genre with awards', async () => {
    shelve('Le Mystère de la chambre jaune', 'Gaston Leroux', 'crime')
    expect(await AwardUseCase.shelf(reader, 'book', 'fr', undefined, now)).toBeNull()
  })

  test('leaves out what the reader holds in the format, by the edition found', async () => {
    sfReader()
    shelve('La Mort de l’auteur', 'Nnedi Okorafor', 'science-fiction')
    deathOfTheAuthorFound()
    const shelf = await AwardUseCase.shelf(reader, 'book', 'fr', undefined, now)
    const locus = shelf?.awards.find((list) => list.award === 'locus-sf')

    expect(locus?.winners).toEqual([])
    expect(locus?.readCount).toBe(1)
    expect(locus?.total).toBe(1)
  })

  test('offers to await what is not out, and not what is awaited already', async () => {
    sfReader()
    const awaited = await AwaitedEditionUseCase.awaitScannedBook(
      reader,
      { ...deathOfTheAuthor, language: 'en', format: 'book' },
      'book',
      'fr',
      now,
    )
    if (typeof awaited === 'string') throw new Error(awaited)
    startFakeRequest()

    const shelf = await AwardUseCase.shelf(reader, 'book', 'fr', undefined, now)
    const views = shelf?.recent ?? []
    const death = views.find((view) => view.work.title === 'Death of the Author')
    const annie = views.find((view) => view.work.title === 'Annie Bot')

    expect(death?.awaitedId).toBe(awaited.id)
    expect(death?.awaitable).toBe(false)
    expect(annie?.awaitable).toBe(true)
    expect(annie?.state).toBe('unannounced')
  })

  test('in English, a printed winner cannot be awaited: it is in English already', async () => {
    sfReader()
    const shelf = await AwardUseCase.shelf(reader, 'book', 'en', undefined, now)
    expect(shelf?.recent.every((view) => !view.awaitable)).toBe(true)
  })

  test('reads the library, the awaited editions, the years found and two getAlls', async () => {
    sfReader()
    startFakeRequest()
    const [docReads, queryReads] = [fake.docReads, fake.queryReads]

    const shelf = await AwardUseCase.shelf(reader, 'book', 'fr', undefined, now)

    expect(fake.queryReads - queryReads).toBe(3)
    // One document per watch looked for, one description per winner with no
    // cover found.
    expect(fake.docReads - docReads).toBeLessThanOrEqual(2 * (shelf?.recent.length ?? 0))
  })
})

describe('the award sections', () => {
  const fantasyReader = () => {
    shelve('Le Sorceleur', 'Andrzej Sapkowski', 'fantasy')
    shelve('Le Nom du vent', 'Patrick Rothfuss', 'fantasy')
    shelve('Assassin royal', 'Robin Hobb', 'fantasy')
  }

  test('draws each winner of the latest ceremonies once, in the genre whose own award crowned it', async () => {
    sfReader()
    fantasyReader()
    const sections = await AwardUseCase.sections(reader, 'book', 'fr', now)
    const titles = (genre: string) =>
      sections.find((section) => section.genre === genre)?.winners.map((view) => view.work.title)

    expect(sections.map((section) => section.genre)).toEqual(['science-fiction', 'fantasy'])
    // A Nebula alone, both genres show it: where the reader reads most.
    expect(titles('science-fiction')).toEqual([
      BookTitle('The Buffalo Hunter Hunter'),
      BookTitle('Death of the Author'),
      BookTitle('Annie Bot'),
    ])
    // Hugo and Locus Fantasy: fantasy, though science fiction is read more.
    expect(titles('fantasy')).toEqual([BookTitle('The Everlasting'), BookTitle('The Tainted Cup')])
    expect(asked).toEqual([])
  })

  test('shows a year found on Wikidata instead of the one before it', async () => {
    sfReader()
    fake.seed('award-winners', 'clarke~2026', {
      key: 'clarke~2026',
      award: 'clarke',
      year: 2026,
      winners: [{ title: 'When There Are Wolves Again', authors: ['E. J. Swift'] }],
      foundAt: now,
    })
    const [sf] = await AwardUseCase.sections(reader, 'book', 'fr', now)
    const titles = sf?.winners.map((view) => view.work.title)

    expect(titles).toContain(BookTitle('When There Are Wolves Again'))
    expect(titles).not.toContain(BookTitle('Annie Bot'))
  })

  test('is empty for a reader of no genre with awards', async () => {
    shelve('Le Mystère de la chambre jaune', 'Gaston Leroux', 'crime')
    expect(await AwardUseCase.sections(reader, 'book', 'fr', now)).toEqual([])
  })
})

describe('the daily winners pass', () => {
  test('asks Wikidata after the latest year known of each award, and keeps a new year', async () => {
    wikidata = {
      clarke: [
        { year: 2024, title: 'In Ascension', authors: ['Martin MacInnes'] },
        { year: 2026, title: 'When There Are Wolves Again', authors: ['E. J. Swift'] },
      ],
    }

    expect(await AwardUseCase.watchWinners(now)).toEqual({ found: 1, failed: 0 })

    expect(wikidataAsked).toContain('clarke>2025')
    expect(wikidataAsked).toContain('hugo>2026')
    expect(fake.data('award-winners', 'clarke~2026')).toMatchObject({
      award: 'clarke',
      year: 2026,
      winners: [{ title: 'When There Are Wolves Again', authors: ['E. J. Swift'] }],
    })
    expect(asked).toEqual([])
  })

  test('asks after the year it found the next day, and finds nothing twice', async () => {
    wikidata = {
      clarke: [{ year: 2026, title: 'When There Are Wolves Again', authors: ['E. J. Swift'] }],
    }
    await AwardUseCase.watchWinners(now)
    wikidataAsked.length = 0

    expect(await AwardUseCase.watchWinners(now)).toEqual({ found: 0, failed: 0 })
    expect(wikidataAsked).toContain('clarke>2026')
  })

  test('keeps no year still to come, and goes on past an award Wikidata fails on', async () => {
    wikidata = {
      hugo: 'down',
      nebula: [{ year: 2027, title: 'Tomorrow', authors: ['Somebody'] }],
      'world-fantasy': [{ year: 2026, title: 'The Next One', authors: ['Somebody Else'] }],
    }

    expect(await AwardUseCase.watchWinners(now)).toEqual({ found: 1, failed: 1 })
    expect(fake.data('award-winners', 'nebula~2027')).toBeNull()
    expect(fake.data('award-winners', 'world-fantasy~2026')).not.toBeNull()
  })
})
