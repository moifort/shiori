import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { graphql } from 'graphql'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

mock.module('~/system/object-store', () => ({
  objectStore: () => ({ downloadUrl: async () => 'https://fake.store/cover' }),
}))

/** Queued Gemini answers, consumed in call order. Nobody pays Google in a test:
 *  what is asserted is what a screen does with an answer. */
let answers: unknown[] = []
const calls: string[] = []

mock.module('~/domain/scan/gemini', () => ({
  generate: async ({ step }: { step: string }) => {
    calls.push(step)
    const value = answers.shift()
    if (value === undefined) throw new Error(`no queued answer for step "${step}"`)
    if (value instanceof Error) throw value
    return { value, usage: { promptTokens: 10, outputTokens: 5, thinkingTokens: 20, searches: 1 } }
  },
}))

const { schema } = await import('~/domain/shared/graphql/schema')

const userId = 'reader-1' as UserId
let fake: ReturnType<typeof resetFakeFirestore>

beforeEach(() => {
  fake = resetFakeFirestore()
  answers = []
  calls.length = 0
})

const execute = (source: string) => graphql({ schema, source, contextValue: { event: {}, userId } })

/** A volume catalogued the way an Audible import or a manual entry catalogues
 *  one: it names its saga and nothing describes that saga anywhere. */
const addVolume = async (
  title: string,
  volume: number,
  options: { author?: string; language?: string } = {},
) => {
  const { author = 'Frank Herbert', language } = options
  const result = await execute(
    `mutation { addBook(input: {
      title: "${title}"
      authors: ["${author}"]
      ${language ? `language: ${language}` : ''}
      series: { id: "dune--frank-herbert", name: "Dune", volume: ${volume}, kind: MAIN }
    }) { id } }`,
  )
  expect(result.errors).toBeUndefined()
  return (result.data as { addBook: { id: string } }).addBook
}

/** Only the fields a given assertion asks for come back, so every one of these
 *  is optional: a query that selects four columns must not have to spell out the
 *  three it deliberately left out. */
type FollowedRow = {
  id: string
  name: string
  author?: string | null
  language?: string | null
  state?: string | null
  ownedCount: number
  catalogue?: { name: string } | null
}

const mySeriesPage = async (limit: number, offset: number) => {
  const result = await execute(
    `{ mySeriesPage(limit: ${limit}, offset: ${offset}) { hasMore items { name } } }`,
  )
  expect(result.errors).toBeUndefined()
  return result.data?.mySeriesPage as { hasMore: boolean; items: { name: string }[] }
}

const mySeries = async () => {
  const result = await execute(
    '{ mySeries { id name author state ownedCount catalogue { name } } }',
  )
  expect(result.errors).toBeUndefined()
  return (result.data as { mySeries: FollowedRow[] }).mySeries
}

describe('the sagas a reader follows', () => {
  // The defect: mySeries used to start from the catalogue, so a saga nobody had
  // ever scanned — every saga an Audible import produces — was absent from the
  // Series tab even though its volumes sat in the library.
  test('follows a saga that has never been catalogued', async () => {
    await addVolume('Dune', 1)
    await addVolume('Le Messie de Dune', 2)

    expect(await mySeries()).toEqual([
      {
        id: 'dune--frank-herbert',
        name: 'Dune',
        author: 'Frank Herbert',
        state: null,
        ownedCount: 2,
        catalogue: null,
      },
    ])
  })

  test('leaves a library of standalone books with no saga to follow', async () => {
    const result = await execute('mutation { addBook(input: { title: "Piranesi" }) { id } }')
    expect(result.errors).toBeUndefined()

    expect(await mySeries()).toEqual([])
  })
})

describe('a saga held in more than one language', () => {
  const followedLanguages = async () => {
    const result = await execute('{ mySeries { id name language ownedCount } }')
    expect(result.errors).toBeUndefined()
    return (result.data as { mySeries: FollowedRow[] }).mySeries
  }

  // Two translations of one saga are two sets of books — other covers, other
  // titles, read at other times — and one row over both hid that.
  test('follows it once per language, sharing one saga id', async () => {
    await addVolume('Dune', 1, { language: 'FR' })
    await addVolume('Dune', 1, { language: 'EN' })

    expect(await followedLanguages()).toEqual([
      { id: 'dune--frank-herbert', name: 'Dune', language: 'EN', ownedCount: 1 },
      { id: 'dune--frank-herbert', name: 'Dune', language: 'FR', ownedCount: 1 },
    ])
  })

  // Unknown is not French: a book catalogued before the scan read languages
  // carries none, and folding it into a language would state what nobody knows.
  test('keeps volumes of unrecorded language in a row of their own, last', async () => {
    await addVolume('Dune', 1, { language: 'FR' })
    await addVolume('Le Messie de Dune', 2)

    expect((await followedLanguages()).map((row) => row.language)).toEqual(['FR', null])
  })

  test('shows one section per language in the library', async () => {
    await addVolume('Dune', 1, { language: 'FR' })
    await addVolume('Dune', 1, { language: 'EN' })

    const result = await execute('{ library { seriesId language books { title } } }')
    expect(result.errors).toBeUndefined()
    expect(result.data?.library).toEqual([
      { seriesId: 'dune--frank-herbert', language: 'EN', books: [{ title: 'Dune' }] },
      { seriesId: 'dune--frank-herbert', language: 'FR', books: [{ title: 'Dune' }] },
    ])
  })
})

describe('opening a saga nobody has catalogued', () => {
  const aCatalogue = {
    name: 'Dune',
    author: 'Frank Herbert',
    description: 'Un désert, une épice, et le fils d’un duc trahi.',
    volumes: [
      { kind: 'main', number: 1, title: 'Dune', publishedIn: 1965 },
      { kind: 'main', number: 2, title: 'Le Messie de Dune', publishedIn: 1969 },
    ],
  }

  const openSeries = async () => {
    const result = await execute(
      '{ series(id: "dune--frank-herbert") { name author spine { number title } } }',
    )
    expect(result.errors).toBeUndefined()
    return result.data?.series
  }

  const described = {
    name: 'Dune',
    author: 'Frank Herbert',
    spine: [
      { number: 1, title: 'Dune' },
      { number: 2, title: 'Le Messie de Dune' },
    ],
  }

  // The defect: a saga an Audible import named had no catalogue, and its screen
  // said so for good — only a scan of one of its volumes built one. Now the
  // screen builds it from the volume the reader already holds, the first time.
  test('catalogues it from the volume the reader holds, and only once', async () => {
    await addVolume('Le Messie de Dune', 2)
    answers = [aCatalogue]

    expect(await openSeries()).toEqual(described)
    expect(calls).toEqual(['catalogue'])

    expect(await openSeries()).toEqual(described)
    expect(calls).toEqual(['catalogue'])
  })

  // Paid for like the third step of a scan, without a scan: the month's counters
  // must say what the catalogue cost, and must not count a scan that never ran.
  test('records what the catalogue call cost, as a catalogue and not a scan', async () => {
    await addVolume('Dune', 1)
    answers = [aCatalogue]

    await openSeries()

    const [usage] = [...fake.snapshot('ai-usage').values()]
    expect(usage).toMatchObject({
      scans: 0,
      cacheHits: 0,
      catalogue: { promptTokens: 10, outputTokens: 5, thinkingTokens: 20, searches: 1 },
    })
  })

  // A reader can only have the world described for sagas they read: nothing in
  // the library names it, so there is no name and no author to ask about.
  test('describes nothing for a saga the reader holds no volume of', async () => {
    expect(await openSeries()).toBeNull()
    expect(calls).toEqual([])
  })

  // The screen says the catalogue is missing rather than failing: the saga is
  // catalogued the next time it is opened, or by the next scan that touches it.
  test('answers with no catalogue, and no error, when the model call fails', async () => {
    await addVolume('Dune', 1)
    answers = [new Error('grounding is down')]

    expect(await openSeries()).toBeNull()
  })

  // Storing an empty catalogue would mark the saga as known and stop any later
  // opening from trying again with better grounding.
  test('stores nothing when the model finds no volumes', async () => {
    await addVolume('Dune', 1)
    answers = [{ ...aCatalogue, volumes: [] }]

    expect(await openSeries()).toBeNull()
    expect(fake.snapshot('series').size).toBe(0)
  })
})

describe('the sagas a reader follows, a page at a time', () => {
  test('serves them in the same order as the whole list, with what follows', async () => {
    for (const name of ['Dune', 'Fondation', 'Hypérion']) {
      const result = await execute(
        `mutation { addBook(input: { title: "${name} 1", authors: ["Auteur"], ` +
          `series: { id: "${name.toLowerCase()}--auteur", name: "${name}", volume: 1, kind: MAIN } }) { id } }`,
      )
      expect(result.errors).toBeUndefined()
    }

    const first = await mySeriesPage(2, 0)
    expect(first).toEqual({ hasMore: true, items: [{ name: 'Dune' }, { name: 'Fondation' }] })

    const second = await mySeriesPage(2, 2)
    expect(second).toEqual({ hasMore: false, items: [{ name: 'Hypérion' }] })
  })
})
