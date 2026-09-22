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
/** The text each step was prompted with, keyed by step. */
const prompts: Record<string, string> = {}

mock.module('~/domain/scan/gemini', () => ({
  generate: async ({ step, parts }: { step: string; parts: { text?: string }[] }) => {
    calls.push(step)
    prompts[step] = parts.map((part) => part.text ?? '').join('')
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
  options: { author?: string; language?: string; status?: string } = {},
) => {
  const { author = 'Frank Herbert', language, status } = options
  const result = await execute(
    `mutation { addBook(input: {
      title: "${title}"
      authors: ["${author}"]
      ${language ? `language: ${language}` : ''}
      ${status ? `status: ${status}` : ''}
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
        state: 'NOT_STARTED',
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

describe('the volumes a reader holds of one saga', () => {
  const volumesOf = async (language?: string) => {
    const result = await execute(
      `{ mySeriesVolumes(seriesId: "dune--frank-herbert"${language ? `, language: ${language}` : ''}) { title coverUrl } }`,
    )
    expect(result.errors).toBeUndefined()
    return (result.data as { mySeriesVolumes: { title: string }[] }).mySeriesVolumes
  }

  test("answers with the saga's volumes only, in the order the saga runs", async () => {
    await addVolume('Le Messie de Dune', 2)
    await addVolume('Dune', 1)
    const standalone = await execute(
      'mutation { addBook(input: { title: "Hypérion", authors: ["Dan Simmons"] }) { id } }',
    )
    expect(standalone.errors).toBeUndefined()

    expect((await volumesOf()).map((volume) => volume.title)).toEqual(['Dune', 'Le Messie de Dune'])
  })

  test('keeps one edition when the reader opened it', async () => {
    await addVolume('Dune', 1, { language: 'FR' })
    await addVolume('Dune (EN)', 1, { language: 'EN' })

    expect((await volumesOf('EN')).map((volume) => volume.title)).toEqual(['Dune (EN)'])
    expect(await volumesOf()).toHaveLength(2)
  })

  test('answers with nothing for a saga the reader holds no volume of', async () => {
    expect(await volumesOf()).toEqual([])
  })

  // The saga screen draws from three root fields; one request carries them all,
  // so the screen pays one round trip rather than three.
  test('opens the whole saga screen in a single request', async () => {
    await addVolume('Dune', 1)
    answers = [
      {
        name: 'Dune',
        author: 'Frank Herbert',
        volumes: [{ kind: 'main', number: 1, title: 'Dune', publishedIn: 1965 }],
      },
    ]

    const result = await execute(`{
      series(id: "dune--frank-herbert") { name }
      seriesOpinion(seriesId: "dune--frank-herbert") { rating }
      mySeriesVolumes(seriesId: "dune--frank-herbert") { title }
    }`)

    expect(result.errors).toBeUndefined()
    expect(result.data).toEqual({
      series: { name: 'Dune' },
      seriesOpinion: null,
      mySeriesVolumes: [{ title: 'Dune' }],
    })
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

  // The defect: a French reader opened a saga they hold in French and got the
  // English titles of its volumes. The catalogue is asked in the language of
  // the edition on the shelf, which is what the reader will look for — and
  // here the request itself carries no language at all, so it answers English.
  test('asks for the catalogue in the language of the edition the reader holds', async () => {
    await addVolume('Le Messie de Dune', 2, { language: 'FR' })
    answers = [aCatalogue]

    await openSeries()

    expect(prompts.catalogue).toContain('Édition : en français.')
  })

  // A saga held in two languages has two rows in the Series tab, and the row
  // the reader opened says which edition they want described.
  test('asks in the language of the edition the reader opened', async () => {
    await addVolume('Dune', 1, { language: 'EN' })
    await addVolume('Dune', 1, { language: 'FR' })
    answers = [aCatalogue]

    const result = await execute('{ series(id: "dune--frank-herbert", language: FR) { name } }')

    expect(result.errors).toBeUndefined()
    expect(prompts.catalogue).toContain('Édition : en français.')
  })
})

describe('refreshing a saga catalogue', () => {
  const stale = {
    name: 'Dune',
    author: 'Frank Herbert',
    volumes: [{ kind: 'main', number: 1, title: 'Dune', publishedIn: 1965 }],
  }
  const fresh = {
    ...stale,
    volumes: [
      ...stale.volumes,
      { kind: 'main', number: 2, title: 'Le Messie de Dune', publishedIn: 1969 },
    ],
  }

  const spineOf = async () => {
    const result = await execute('{ series(id: "dune--frank-herbert") { spine { title } } }')
    expect(result.errors).toBeUndefined()
    return (result.data?.series as { spine: { title: string }[] } | null)?.spine
  }

  const refresh = async () => {
    const result = await execute(
      'mutation { refreshSeries(seriesId: "dune--frank-herbert") { spine { title } } }',
    )
    expect(result.errors).toBeUndefined()
    return result.data?.refreshSeries as { spine: { title: string }[] } | null
  }

  // A catalogue is written once and read by everyone, so a volume announced
  // after that first call never appears — nor does a wrong-language catalogue
  // ever get another chance. The reader can ask the world again.
  test('replaces the stored catalogue with a fresh model call', async () => {
    await addVolume('Dune', 1, { language: 'FR' })
    answers = [stale]
    await spineOf()

    answers = [fresh]
    expect(await refresh()).toEqual({
      spine: [{ title: 'Dune' }, { title: 'Le Messie de Dune' }],
    })

    expect(calls).toEqual(['catalogue', 'catalogue'])
    expect(await spineOf()).toEqual([{ title: 'Dune' }, { title: 'Le Messie de Dune' }])
    expect(prompts.catalogue).toContain('Édition : en français.')
  })

  // A failed refresh must not cost the reader the catalogue they had: the
  // screen keeps showing it, and says the refresh did not go through.
  test('keeps the previous catalogue when the model fails or finds nothing', async () => {
    await addVolume('Dune', 1)
    answers = [stale]
    await spineOf()

    answers = [new Error('grounding is down')]
    expect(await refresh()).toBeNull()
    answers = [{ ...stale, volumes: [] }]
    expect(await refresh()).toBeNull()

    expect(await spineOf()).toEqual([{ title: 'Dune' }])
  })

  test('refreshes nothing for a saga the reader holds no volume of', async () => {
    expect(await refresh()).toBeNull()
    expect(calls).toEqual([])
  })
})

describe('the sagas a reader follows, a page at a time', () => {
  test('cuts the pages from one order, with what follows', async () => {
    for (const name of ['Dune', 'Fondation', 'Hypérion']) {
      const result = await execute(
        `mutation { addBook(input: { title: "${name} 1", authors: ["Auteur"], ` +
          `series: { id: "${name.toLowerCase()}--auteur", name: "${name}", volume: 1, kind: MAIN } }) { id } }`,
      )
      expect(result.errors).toBeUndefined()
    }

    const whole = await mySeriesPage(10, 0)
    expect(whole.items).toHaveLength(3)

    const first = await mySeriesPage(2, 0)
    expect(first).toEqual({ hasMore: true, items: whole.items.slice(0, 2) })

    const second = await mySeriesPage(2, 2)
    expect(second).toEqual({ hasMore: false, items: whole.items.slice(2) })
  })
})

describe('the Series tab, newest first', () => {
  const addSaga = async (name: string, genre: string, volume = 1) => {
    const result = await execute(
      `mutation { addBook(input: { title: "${name} ${volume}", authors: ["Auteur"], genre: ${genre}, ` +
        `series: { id: "${name.toLowerCase()}--auteur", name: "${name}", volume: ${volume}, kind: MAIN } }) { id } }`,
    )
    expect(result.errors).toBeUndefined()
    return (result.data as { addBook: { id: string } }).addBook.id
  }

  const setStatus = async (bookId: string, status: string) => {
    const result = await execute(
      `mutation { setReadingStatus(id: "${bookId}", status: ${status}) { id } }`,
    )
    expect(result.errors).toBeUndefined()
  }

  // Paginated, the phone cannot order rows itself without a page landing late
  // reshuffling what is drawn: the pages come ordered, the phone cuts months.
  test('orders the sagas on their latest shelved volume, whatever their genre or state', async () => {
    const finished = await addSaga('Berserk', 'FANTASY')
    const started = await addSaga('Culture', 'SCIENCE_FICTION')
    // Two stamps in one millisecond would tie and keep the incoming order.
    await Bun.sleep(5)
    await addSaga('Anathem', 'SCIENCE_FICTION')
    await Bun.sleep(5)
    await setStatus(started, 'READING')
    await Bun.sleep(5)
    await setStatus(finished, 'READ')

    const result = await execute('{ mySeriesPage(limit: 10) { items { name state shelvedAt } } }')
    expect(result.errors).toBeUndefined()
    const { items } = (
      result.data as {
        mySeriesPage: { items: { name: string; state: string | null; shelvedAt: string }[] }
      }
    ).mySeriesPage
    expect(items.map(({ name, state }) => ({ name, state }))).toEqual([
      { name: 'Berserk', state: null },
      { name: 'Culture', state: 'IN_PROGRESS' },
      { name: 'Anathem', state: 'NOT_STARTED' },
    ])
    const dates = items.map((item) => Date.parse(item.shelvedAt))
    expect(dates).toEqual([...dates].sort((left, right) => right - left))
  })

  // A saga is dated by its most recent volume, not by its first.
  test('dates a saga by the volume shelved last', async () => {
    const first = await addSaga('Dune', 'SCIENCE_FICTION')
    await Bun.sleep(5)
    await addSaga('Wheel', 'FANTASY')
    await Bun.sleep(5)
    await addSaga('Dune', 'SCIENCE_FICTION', 2)
    expect(first).toBeString()

    const result = await execute('{ mySeriesPage(limit: 10) { items { name } } }')
    expect(result.errors).toBeUndefined()
    expect(result.data?.mySeriesPage).toEqual({ items: [{ name: 'Dune' }, { name: 'Wheel' }] })
  })

  test('keeps only the hearted sagas, or those in one state', async () => {
    const finished = await addSaga('Berserk', 'FANTASY')
    await addSaga('Dune', 'SCIENCE_FICTION')
    await setStatus(finished, 'READ')
    await execute(
      'mutation { setSeriesFavorite(seriesId: "dune--auteur", favorite: true) { favorite } }',
    )

    const hearted = await execute('{ mySeriesPage(favorite: true) { items { name } } }')
    expect(hearted.data?.mySeriesPage).toEqual({ items: [{ name: 'Dune' }] })

    // Every owned volume read and no catalogue: unknown, kept with the complete.
    const complete = await execute('{ mySeriesPage(state: COMPLETE) { items { name } } }')
    expect(complete.data?.mySeriesPage).toEqual({ items: [{ name: 'Berserk' }] })
  })
})

describe('removing a saga from the library', () => {
  test('removes every volume and the opinion, and nothing else', async () => {
    await addVolume('Dune', 1)
    await addVolume('Le Messie de Dune', 2)
    await execute(
      'mutation { addBook(input: { title: "Hypérion", authors: ["Dan Simmons"] }) { id } }',
    )
    await execute('mutation { rateSeries(seriesId: "dune--frank-herbert", rating: 4) { rating } }')

    const removed = await execute('mutation { deleteSeries(seriesId: "dune--frank-herbert") }')
    expect(removed.errors).toBeUndefined()
    expect(removed.data?.deleteSeries).toBe(2)

    const left = await execute(
      '{ mySeries { name } seriesOpinion(seriesId: "dune--frank-herbert") { rating } }',
    )
    expect(left.data).toEqual({ mySeries: [], seriesOpinion: null })
  })

  // The Series tab shows a saga held in two languages as two rows, and the
  // reader removes the row they see: the other edition is a different set of
  // books, and their opinion is of the work, which they still hold.
  test('removes one edition of a saga and leaves the other, with the opinion', async () => {
    await addVolume('Dune', 1, { language: 'EN' })
    await addVolume('Dune Messiah', 2, { language: 'EN' })
    await addVolume('Dune', 1, { language: 'FR' })
    await execute('mutation { rateSeries(seriesId: "dune--frank-herbert", rating: 4) { rating } }')

    const removed = await execute(
      'mutation { deleteSeries(seriesId: "dune--frank-herbert", language: EN) }',
    )
    expect(removed.errors).toBeUndefined()
    expect(removed.data?.deleteSeries).toBe(2)

    const left = await execute(
      '{ mySeries { language ownedCount } seriesOpinion(seriesId: "dune--frank-herbert") { rating } }',
    )
    expect(left.data).toEqual({
      mySeries: [{ language: 'FR', ownedCount: 1 }],
      seriesOpinion: { rating: 4 },
    })
  })

  test('forgets the opinion once the last edition is gone', async () => {
    await addVolume('Dune', 1, { language: 'EN' })
    await execute('mutation { rateSeries(seriesId: "dune--frank-herbert", rating: 4) { rating } }')

    await execute('mutation { deleteSeries(seriesId: "dune--frank-herbert", language: EN) }')

    const left = await execute('{ seriesOpinion(seriesId: "dune--frank-herbert") { rating } }')
    expect(left.data).toEqual({ seriesOpinion: null })
  })

  test('removes nothing from a saga the reader holds no volume of', async () => {
    const removed = await execute('mutation { deleteSeries(seriesId: "dune--frank-herbert") }')
    expect(removed.data?.deleteSeries).toBe(0)
  })
})

describe('a saga the reader counted themselves', () => {
  const DUNE = 'dune--frank-herbert'
  const aCatalogue = {
    name: 'Dune',
    author: 'Frank Herbert',
    volumes: [
      { kind: 'main', number: 1, title: 'Dune', publishedIn: 1965 },
      { kind: 'main', number: 2, title: 'Le Messie de Dune', publishedIn: 1969 },
    ],
  }

  const declare = async (count: number) => {
    const result = await execute(
      `mutation { declareSeriesVolumeCount(seriesId: "${DUNE}", count: ${count}) { volumeCount } }`,
    )
    expect(result.errors).toBeUndefined()
    return result.data?.declareSeriesVolumeCount
  }

  const openSeries = async () => {
    const result = await execute(
      `{ series(id: "${DUNE}") { name author provisional spine { number title } } }`,
    )
    expect(result.errors).toBeUndefined()
    return result.data?.series
  }

  // The model failed or was never asked, and the reader knows the saga has
  // three volumes: their screen draws those three, theirs by their titles, the
  // rest by the saga's name — without a model call on every opening.
  test('draws the declared count as a catalogue, without asking the model', async () => {
    await addVolume('Le Messie de Dune', 2)

    expect(await declare(3)).toEqual({ volumeCount: 3 })
    expect(await openSeries()).toEqual({
      name: 'Dune',
      author: 'Frank Herbert',
      provisional: true,
      spine: [
        { number: 1, title: 'Dune' },
        { number: 2, title: 'Le Messie de Dune' },
        { number: 3, title: 'Dune' },
      ],
    })
    expect(calls).toEqual([])
  })

  test('never writes the count into the shared catalogue', async () => {
    await addVolume('Dune', 1)

    await declare(3)
    await openSeries()

    expect(fake.data('series', DUNE)).toBeNull()
  })

  test('measures the saga against the declared count on the Series tab', async () => {
    await addVolume('Dune', 1, { status: 'READ' })
    await declare(3)

    const result = await execute(
      '{ mySeries { state progress { readCount totalCount } catalogue { provisional } } }',
    )
    expect(result.errors).toBeUndefined()
    expect(result.data?.mySeries).toEqual([
      {
        state: 'IN_PROGRESS',
        progress: { readCount: 1, totalCount: 3 },
        catalogue: { provisional: true },
      },
    ])
  })

  test('measures the saga against the declared count on the dashboard', async () => {
    await addVolume('Dune', 1, { status: 'READ' })
    await declare(3)

    const result = await execute(
      '{ dashboard(timeZone: "Europe/Paris") { series { name readCount totalCount } } }',
    )
    expect(result.errors).toBeUndefined()
    expect(result.data?.dashboard).toEqual({
      series: [{ name: 'Dune', readCount: 1, totalCount: 3 }],
    })
  })

  // The count is a stopgap: the world's own catalogue wins the day it is asked.
  test('gives way to the catalogue the model builds on demand', async () => {
    await addVolume('Le Messie de Dune', 2)
    await declare(3)
    answers = [aCatalogue]

    const refreshed = await execute(
      `mutation { refreshSeries(seriesId: "${DUNE}") { provisional spine { number } } }`,
    )
    expect(refreshed.errors).toBeUndefined()
    expect(refreshed.data?.refreshSeries).toEqual({
      provisional: false,
      spine: [{ number: 1 }, { number: 2 }],
    })

    expect(await openSeries()).toMatchObject({ provisional: false })
    expect(calls).toEqual(['catalogue'])
  })
})

describe('a saga the reader stopped following', () => {
  const DUNE = 'dune--frank-herbert'
  const unfollow = async (followed = false) => {
    const result = await execute(
      `mutation { setSeriesFollowed(seriesId: "${DUNE}", followed: ${followed}) { followed } }`,
    )
    expect(result.errors).toBeUndefined()
    return result.data?.setSeriesFollowed
  }
  const states = async (filter = '') => {
    const result = await execute(`{ mySeriesPage${filter} { items { name state } } }`)
    expect(result.errors).toBeUndefined()
    return (result.data as { mySeriesPage: { items: { name: string; state: string }[] } })
      .mySeriesPage.items
  }

  test('is set aside in a state of its own, out of the sagas in progress', async () => {
    await addVolume('Dune', 1, { status: 'READING' })

    expect(await unfollow()).toEqual({ followed: false })

    // Out of the reader's way: only its own filter shows it.
    expect(await states()).toEqual([])
    expect(await states('(state: IN_PROGRESS)')).toEqual([])
    expect(await states('(state: UNFOLLOWED)')).toEqual([{ name: 'Dune', state: 'UNFOLLOWED' }])
  })

  test('takes its place back once the reader follows it again', async () => {
    await addVolume('Dune', 1, { status: 'READING' })
    await unfollow()

    expect(await unfollow(true)).toEqual({ followed: true })
    expect(await states()).toEqual([{ name: 'Dune', state: 'IN_PROGRESS' }])
  })

  // Two editions are two sets of books: setting the English one aside says
  // nothing about the French one on the shelf beside it.
  test('sets aside one edition, and leaves the other followed', async () => {
    await addVolume('Dune', 1, { language: 'FR', status: 'READING' })
    await addVolume('Dune', 1, { language: 'EN', status: 'READING' })
    const setEnglish = async (followed: boolean) => {
      const result = await execute(
        `mutation { setSeriesFollowed(seriesId: "${DUNE}", followed: ${followed}, language: EN) {
          followed unfollowedLanguages
        } }`,
      )
      expect(result.errors).toBeUndefined()
      return result.data?.setSeriesFollowed
    }
    const editions = async (filter = '') => {
      const result = await execute(`{ mySeriesPage${filter} { items { language state } } }`)
      expect(result.errors).toBeUndefined()
      const items = (
        result.data as { mySeriesPage: { items: { language: string; state: string }[] } }
      ).mySeriesPage.items
      return [...items].sort((left, right) => left.language.localeCompare(right.language))
    }

    expect(await setEnglish(false)).toEqual({ followed: true, unfollowedLanguages: ['EN'] })
    expect(await editions()).toEqual([{ language: 'FR', state: 'IN_PROGRESS' }])
    expect(await editions('(state: UNFOLLOWED)')).toEqual([{ language: 'EN', state: 'UNFOLLOWED' }])

    expect(await setEnglish(true)).toEqual({ followed: true, unfollowedLanguages: [] })
    expect(await editions()).toEqual([
      { language: 'EN', state: 'IN_PROGRESS' },
      { language: 'FR', state: 'IN_PROGRESS' },
    ])
  })

  // Without an edition, from the dashboard card that draws them all as one,
  // the whole saga is set aside.
  test('sets aside every edition when none is named', async () => {
    await addVolume('Dune', 1, { language: 'FR', status: 'READING' })
    await addVolume('Dune', 1, { language: 'EN', status: 'READING' })

    await unfollow()

    const result = await execute('{ mySeriesPage(state: UNFOLLOWED) { items { state } } }')
    expect(result.data?.mySeriesPage).toEqual({
      items: [{ state: 'UNFOLLOWED' }, { state: 'UNFOLLOWED' }],
    })
  })

  test('leaves the volumes as they were', async () => {
    await addVolume('Dune', 1, { status: 'READING' })
    await unfollow()

    const result = await execute('{ libraryPage { books { title status } } }')
    expect(result.data?.libraryPage).toEqual({ books: [{ title: 'Dune', status: 'READING' }] })
  })
})

describe('one row of the Series tab', () => {
  const followedRow = async (language?: string) => {
    const result = await execute(
      `{ myFollowedSeries(seriesId: "dune--frank-herbert"${language ? `, language: ${language}` : ''}) {
        name language ownedCount
      } }`,
    )
    expect(result.errors).toBeUndefined()
    return result.data?.myFollowedSeries
  }

  test('answers the edition asked for', async () => {
    await addVolume('Dune', 1, { language: 'FR' })
    await addVolume('Le Messie de Dune', 2, { language: 'FR' })
    await addVolume('Dune', 1, { language: 'EN' })

    expect(await followedRow('FR')).toEqual({ name: 'Dune', language: 'FR', ownedCount: 2 })
  })

  test('answers nothing once the reader holds none of it', async () => {
    await addVolume('Dune', 1, { language: 'FR' })

    expect(await followedRow('EN')).toBeNull()
  })
})
