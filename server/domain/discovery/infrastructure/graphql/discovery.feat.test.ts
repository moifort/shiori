import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { graphql } from 'graphql'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore, startFakeRequest } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/object-store', () => ({
  objectStore: () => ({ downloadUrl: async () => 'https://fake.store/cover' }),
}))

const { schema } = await import('~/domain/shared/graphql/schema')
const { BookUseCase } = await import('~/domain/book/use-case')
const { SeriesName, VolumeNumber, seriesKeyOf } = await import('~/domain/series/primitives')
const { AuthorName, BookTitle } = await import('~/domain/shared/primitives')

const bob = 'bob' as UserId
const run = (source: string) =>
  graphql({ schema, source, contextValue: { event: {}, userId: bob } })
const carl = seriesKeyOf('Dungeon Crawler Carl', 'Matt Dinniman', 'book')

let fake = resetFakeFirestore()

beforeEach(async () => {
  fake = resetFakeFirestore()
  await BookUseCase.add(bob, {
    title: BookTitle('Carl 1'),
    authors: [AuthorName('Matt Dinniman')],
    status: 'read',
    language: 'fr',
    series: {
      id: carl,
      name: SeriesName('Dungeon Crawler Carl'),
      volume: VolumeNumber(1),
      kind: 'main',
    },
  })
  fake.seed('saga-watches', `${carl}--fr`, {
    key: `${carl}--fr`,
    seriesId: carl,
    name: 'Dungeon Crawler Carl',
    author: 'Matt Dinniman',
    language: 'fr',
    checkedAt: new Date(),
    volumes: [
      { number: 2, title: 'Carl 2', date: '2025-01-15', isbn13: '9782226488176' },
      { number: 4, title: 'Carl 4', date: '2099-02-12' },
    ],
  })
})

describe('the Découvrir tab', () => {
  test('answers a row per saga of the format asked, with what it has for the reader', async () => {
    const result = await run(`{
      discovery(format: BOOK) {
        unwatched
        sagas {
          series { id name language ownedCount }
          next { number date }
          missing
        }
      }
    }`)

    expect(result.errors).toBeUndefined()
    expect(result.data?.discovery).toEqual({
      unwatched: 0,
      sagas: [
        {
          series: { id: carl, name: 'Dungeon Crawler Carl', language: 'FR', ownedCount: 1 },
          next: { number: 4, date: '2099-02-12' },
          missing: [2],
        },
      ],
    })
  })

  test('answers nothing in the other format', async () => {
    const result = await run(
      '{ discovery(format: AUDIOBOOK) { unwatched followed sagas { series { id } } } }',
    )
    expect(result.data?.discovery).toEqual({ unwatched: 0, followed: 0, sagas: [] })
  })

  // The row draws every cover the Series tab draws: the catalogue's spine
  // comes with it.
  test('carries the catalogue spine the Series tab draws its strip from', async () => {
    fake.seed('series', carl, {
      id: carl,
      name: 'Dungeon Crawler Carl',
      author: 'Matt Dinniman',
      catalogedAt: new Date(),
      volumes: [1, 2, 3, 4].map((number) => ({
        number,
        title: `Carl ${number}`,
        kind: 'main',
        publishedIn: number === 4 ? 2099 : 2020,
      })),
    })
    startFakeRequest()

    const result = await run(
      '{ discovery(format: BOOK) { sagas { series { catalogue { spine { number } } } } } }',
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.discovery).toEqual({
      sagas: [{ series: { catalogue: { spine: [1, 2, 3, 4].map((number) => ({ number })) } } }],
    })
  })
})

describe('an announced recording', () => {
  const audioCarl = seriesKeyOf('Dungeon Crawler Carl', 'Matt Dinniman', 'audiobook')

  beforeEach(async () => {
    await BookUseCase.add(bob, {
      title: BookTitle('Carl 1'),
      authors: [AuthorName('Matt Dinniman')],
      status: 'read',
      format: 'audiobook',
      language: 'fr',
      series: {
        id: audioCarl,
        name: SeriesName('Dungeon Crawler Carl'),
        volume: VolumeNumber(1),
        kind: 'main',
      },
    })
    fake.seed('saga-watches', `${audioCarl}--fr`, {
      key: `${audioCarl}--fr`,
      seriesId: audioCarl,
      name: 'Dungeon Crawler Carl',
      author: 'Matt Dinniman',
      language: 'fr',
      checkedAt: new Date(),
      volumes: [{ number: 2, title: 'Carl 2', date: '2099-02-12', asin: 'B0DM67WR2V' }],
    })
  })

  test('links to its page on the reader’s Audible store', async () => {
    fake.seed('audible-connections', bob, {
      userId: bob,
      account: { marketplace: 'fr', connectedAt: new Date() },
    })
    startFakeRequest()

    const result = await run('{ discovery(format: AUDIOBOOK) { sagas { next { audibleUrl } } } }')

    expect(result.errors).toBeUndefined()
    expect(result.data?.discovery).toEqual({
      sagas: [{ next: { audibleUrl: 'https://www.audible.fr/pd/B0DM67WR2V' } }],
    })
  })

  test('has no link without an Audible account', async () => {
    const result = await run('{ discovery(format: AUDIOBOOK) { sagas { next { audibleUrl } } } }')

    expect(result.data?.discovery).toEqual({ sagas: [{ next: { audibleUrl: null } }] })
  })
})

describe('an announced volume’s page', () => {
  test('is refused for a volume no watch announced', async () => {
    const result = await run(
      `mutation { previewAnnouncedVolume(seriesId: "${carl}", language: FR, number: 9) { releaseDate } }`,
    )
    expect(result.errors?.[0]?.extensions?.code).toBe('NOT_FOUND')
  })
})

describe('the saga screen', () => {
  test('says what the saga has for the reader in the edition opened', async () => {
    const result = await run(
      `{ sagaReleases(seriesId: "${carl}", language: FR) { watched next { number } } }`,
    )
    expect(result.errors).toBeUndefined()
    expect(result.data?.sagaReleases).toEqual({
      watched: true,
      next: { number: 4 },
    })
  })
})
