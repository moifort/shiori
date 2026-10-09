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

/** Stands in for Gemini: the edition asked about, as `answers` holds it by the
 *  title it won under, and every title asked about. */
const asked: string[] = []
let answers: Record<string, unknown> = {}
mock.module('~/domain/scan/gemini', () => ({
  generate: async ({ parts }: { parts: { text: string }[] }) => {
    const title = parts[0]?.text.match(/« ([^»]+) »/)?.[1] ?? '?'
    asked.push(title)
    return {
      usage: { promptTokens: 1, outputTokens: 1, thinkingTokens: 0, searches: 1 },
      value: answers[title] ?? { found: false },
    }
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
const { RECENT_COUNT } = await import('~/domain/award/business-rules')
const { WINNERS } = await import('~/domain/award/winners')
const { AWARDS: WINNER_AWARDS } = await import('~/domain/award/types')
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

/** A science fiction reader: three novels read, one of them a Hugo winner in
 *  French, and Dune on the pile. */
const sfReader = () => {
  shelve('Les Cantos d’Hypérion', 'Dan Simmons', 'science-fiction')
  shelve('Fondation', 'Isaac Asimov', 'science-fiction')
  shelve('La Stratégie Ender', 'Orson Scott Card', 'science-fiction')
  shelve('Dune', 'Frank Herbert', 'science-fiction', 'to-read')
}

/** What the web found of Hyperion in French, as the hourly pass kept it. */
const hyperionFound = () =>
  fake.seed('edition-watches', 'hyperion--dan-simmons--book--fr', {
    key: 'hyperion--dan-simmons--book--fr',
    title: 'Hyperion',
    author: 'Dan Simmons',
    originalLanguage: 'en',
    format: 'book',
    language: 'fr',
    checkedAt: now,
    found: { title: 'Les Cantos d’Hypérion', date: '1991-06-01' },
  })

beforeEach(() => {
  fake = resetFakeFirestore()
  asked.length = 0
  answers = {}
  shelved = 0
})

describe('the award shelf', () => {
  test('is the genre the reader reads most, its own awards first', async () => {
    sfReader()
    const shelf = await AwardUseCase.shelf(reader, 'book', 'fr', undefined, now)

    expect(shelf?.genre).toBe('science-fiction')
    expect(shelf?.genres).toEqual(['science-fiction'])
    expect(shelf?.awards.map((list) => list.award)).toEqual([
      'hugo',
      'nebula',
      'locus-sf',
      'clarke',
    ])
    expect(shelf?.recent).toHaveLength(12)
    expect(shelf?.recent[0]?.work.title).toBe(BookTitle('The Everlasting'))
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
    hyperionFound()
    const shelf = await AwardUseCase.shelf(reader, 'book', 'fr', undefined, now)
    const hugo = shelf?.awards.find((list) => list.award === 'hugo')
    const titles = hugo?.winners.map((view) => view.work.title) ?? []

    expect(titles).not.toContain(BookTitle('Hyperion'))
    expect(titles).not.toContain(BookTitle('Dune'))
    expect(titles).toContain(BookTitle('Neuromancer'))
    expect(hugo?.readCount).toBe(1)
    expect(hugo?.total).toBe(hugo ? hugo.winners.length + 2 : 0)
  })

  test('offers to await what is not out, and not what is awaited already', async () => {
    sfReader()
    const awaited = await AwaitedEditionUseCase.awaitScannedBook(
      reader,
      {
        title: BookTitle('Neuromancer'),
        authors: [AuthorName('William Gibson')],
        language: 'en',
        format: 'book',
      },
      'book',
      'fr',
      now,
    )
    if (typeof awaited === 'string') throw new Error(awaited)
    startFakeRequest()

    const shelf = await AwardUseCase.shelf(reader, 'book', 'fr', undefined, now)
    const views = shelf?.awards.flatMap((list) => list.winners) ?? []
    const neuromancer = views.find((view) => view.work.title === 'Neuromancer')
    const gateway = views.find((view) => view.work.title === 'Gateway')

    expect(neuromancer?.awaitedId).toBe(awaited.id)
    expect(neuromancer?.awaitable).toBe(false)
    expect(gateway?.awaitable).toBe(true)
    expect(gateway?.state).toBe('unannounced')
  })

  test('in English, a printed winner cannot be awaited: it is in English already', async () => {
    sfReader()
    const shelf = await AwardUseCase.shelf(reader, 'book', 'en', undefined, now)
    expect(shelf?.recent.every((view) => !view.awaitable)).toBe(true)
  })

  test('switches to another genre the reader reads enough, never to one they do not', async () => {
    sfReader()
    shelve('Le Sorceleur', 'Andrzej Sapkowski', 'fantasy')
    shelve('Le Nom du vent', 'Patrick Rothfuss', 'fantasy')
    shelve('Assassin royal', 'Robin Hobb', 'fantasy')

    const fantasy = await AwardUseCase.shelf(reader, 'book', 'fr', 'fantasy', now)
    expect(fantasy?.genre).toBe('fantasy')
    expect(fantasy?.awards[0]?.award).toBe('world-fantasy')

    const horror = await AwardUseCase.shelf(reader, 'book', 'fr', 'horror', now)
    expect(horror?.genre).toBe('science-fiction')
  })

  test('reads the library, the awaited editions, the interest and two getAlls', async () => {
    sfReader()
    await AwardUseCase.shelf(reader, 'book', 'fr', undefined, now)
    startFakeRequest()
    const [docReads, queryReads] = [fake.docReads, fake.queryReads]

    const shelf = await AwardUseCase.shelf(reader, 'book', 'fr', undefined, now)

    const works = new Set(shelf?.awards.flatMap((list) => list.winners.map((v) => v.work.key)))
    expect(fake.queryReads - queryReads).toBe(2)
    // One document per watch looked for, held or not, plus the interest, plus
    // one description per winner on the strip with no cover found.
    expect(fake.docReads - docReads).toBeGreaterThanOrEqual(works.size + 1)
    expect(fake.docReads - docReads).toBeLessThanOrEqual(works.size + 3 + RECENT_COUNT)
  })

  test('marks the genre as looked at, once a day', async () => {
    sfReader()
    await AwardUseCase.shelf(reader, 'book', 'fr', undefined, now)
    await AwardUseCase.shelf(reader, 'audiobook', 'fr', undefined, new Date(now.getTime() + 1000))

    expect(fake.data('award-interests', 'science-fiction--fr')).toMatchObject({
      genre: 'science-fiction',
      language: 'fr',
      requestedAt: now,
    })
  })
})

describe('the award sections', () => {
  const fantasyReader = () => {
    shelve('Le Sorceleur', 'Andrzej Sapkowski', 'fantasy')
    shelve('Le Nom du vent', 'Patrick Rothfuss', 'fantasy')
    shelve('Assassin royal', 'Robin Hobb', 'fantasy')
  }

  test('gives each genre the reader reads enough a section, the most read first', async () => {
    sfReader()
    fantasyReader()
    const sections = await AwardUseCase.sections(reader, 'book', 'fr', now)

    expect(sections.map((section) => section.genre)).toEqual(['science-fiction', 'fantasy'])
    expect(sections.every((section) => section.winners.length === RECENT_COUNT)).toBe(true)
  })

  test('draws every winner once, in the genre whose own award crowned it', async () => {
    sfReader()
    fantasyReader()
    const [sf, fantasy] = await AwardUseCase.sections(reader, 'book', 'fr', now)
    const titles = (section: typeof sf) => section?.winners.map((view) => view.work.title) ?? []

    // Hugo and Locus Fantasy: fantasy, though science fiction is read more.
    expect(titles(fantasy)).toContain(BookTitle('The Everlasting'))
    expect(titles(sf)).not.toContain(BookTitle('The Everlasting'))
    // A Nebula alone, both genres show it: where the reader reads most.
    expect(titles(sf).slice(0, 2)).toEqual([
      BookTitle('The Buffalo Hunter Hunter'),
      BookTitle('Death of the Author'),
    ])
    expect(titles(sf).filter((title) => titles(fantasy).includes(title))).toEqual([])
  })

  test('is empty for a reader of no genre with awards', async () => {
    shelve('Le Mystère de la chambre jaune', 'Gaston Leroux', 'crime')
    expect(await AwardUseCase.sections(reader, 'book', 'fr', now)).toEqual([])
  })

  test('marks each genre shown as looked at', async () => {
    sfReader()
    fantasyReader()
    await AwardUseCase.sections(reader, 'book', 'fr', now)

    expect(fake.data('award-interests', 'science-fiction--fr')).toMatchObject({ language: 'fr' })
    expect(fake.data('award-interests', 'fantasy--fr')).toMatchObject({ language: 'fr' })
  })

  test('reads the library, the awaited editions, the interests and two getAlls', async () => {
    sfReader()
    fantasyReader()
    await AwardUseCase.sections(reader, 'book', 'fr', now)
    startFakeRequest()
    const [docReads, queryReads] = [fake.docReads, fake.queryReads]

    await AwardUseCase.sections(reader, 'book', 'fr', now)

    const works = new Set(
      [...WINNER_AWARDS].flatMap((award) => WINNERS[award].map(([, title]) => title)),
    )
    expect(fake.queryReads - queryReads).toBe(2)
    // One document per watch, the two interests, a description per winner shown.
    expect(fake.docReads - docReads).toBeLessThanOrEqual(works.size + 2 + 2 * RECENT_COUNT)
  })
})

describe('the hourly pass', () => {
  test('looks up nothing when nobody looked at any genre', async () => {
    expect(await AwardUseCase.watchDue(now)).toEqual({ watched: 0, failed: 0, deferred: 0 })
    expect(asked).toEqual([])
  })

  test('looks up the winners of a genre looked at, both formats, until the budget is spent', async () => {
    sfReader()
    await AwardUseCase.shelf(reader, 'book', 'fr', undefined, now)
    answers = { Hyperion: { found: true, title: 'Les Cantos d’Hypérion', date: '1991-06-01' } }

    const run = await AwardUseCase.watchDue(now, 0, Date.now() - 1)
    expect(run.watched).toBe(0)
    expect(run.deferred).toBeGreaterThan(0)

    const all = await AwardUseCase.watchDue(now)
    expect(all.failed).toBe(0)
    expect(all.deferred).toBe(0)
    expect(asked.filter((title) => title === 'Hyperion')).toHaveLength(2)
    expect(fake.data('edition-watches', 'hyperion--dan-simmons--book--fr')).toMatchObject({
      found: { title: 'Les Cantos d’Hypérion' },
    })

    asked.length = 0
    expect((await AwardUseCase.watchDue(now)).watched).toBe(0)
    expect(asked).toEqual([])
  })

  test('forgets a genre nobody looked at for three months', async () => {
    fake.seed('award-interests', 'science-fiction--fr', {
      key: 'science-fiction--fr',
      genre: 'science-fiction',
      language: 'fr',
      requestedAt: new Date(now.getTime() - 91 * 86_400_000),
    })
    expect((await AwardUseCase.watchDue(now)).watched).toBe(0)
  })
})
