import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import { type FakeFirestore, fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/config', () => ({
  config: () => ({ googleApiKey: 'test-key', premiumUserIds: [] }),
}))

/** Stands in for Gemini's grounded step: what it was asked about, and a
 *  description of the fourth volume. */
const asked: string[] = []
mock.module('~/domain/scan/gemini', () => ({
  generate: async ({ parts }: { parts: { text: string }[] }) => {
    asked.push(parts[0]?.text ?? '')
    return {
      usage: { promptTokens: 10, outputTokens: 5, thinkingTokens: 0, searches: 1 },
      value: {
        title: 'Carl 4',
        authors: ['Matt Dinniman'],
        synopsis: 'Carl descend au quatrième étage.',
        genre: 'fantasy',
        subgenres: ['LitRPG'],
        firstPublishedIn: 2022,
        pageCount: 612,
        seriesName: 'Dungeon Crawler Carl',
        volumeNumber: 4,
        volumeKind: 'main',
      },
    }
  },
}))
mock.module('~/domain/scan/published-cover', () => ({
  publishedCoverOf: async () => undefined,
  isCoverGone: async () => false,
}))

/** Audible sells the recording, read by Jeff Hays. */
const searchedAudible: string[] = []
mock.module('~/domain/discovery/infrastructure/audible-catalogue', () => ({
  audibleEditionOf: async (title: string) => {
    searchedAudible.push(title)
    return {
      title,
      authors: ['Matt Dinniman'],
      narrators: ['Jeff Hays'],
      publisher: 'Audible Studios',
      synopsis: 'Le livre audio événement !',
      durationMinutes: 1200,
      coverUrl: 'https://m.media-amazon.com/carl4.jpg',
    }
  },
  audibleProductOf: async () => 'unknown',
  audibleSeriesOf: async () => 'unknown',
  audibleRecordingOf: async () => 'unknown',
}))

const { DiscoveryUseCase } = await import('~/domain/discovery/use-case')
const { monthOf } = await import('~/domain/quota/business-rules')
const { VolumeNumber, seriesKeyOf } = await import('~/domain/series/primitives')

const reader = 'reader' as UserId
const other = 'other' as UserId
const printed = seriesKeyOf('Dungeon Crawler Carl', 'Matt Dinniman', 'book')
let fake: FakeFirestore

const quotaDoc = (userId: UserId) => `${userId}_${monthOf(new Date())}`
const spent = (userId: UserId) =>
  (fake.data('ai-quotas', quotaDoc(userId)) as { scans: number } | null)?.scans ?? 0

const volume = {
  title: 'Carl 4',
  authors: ['Matt Dinniman'],
  format: 'book',
  language: 'fr',
  series: { id: printed, name: 'Dungeon Crawler Carl', volume: VolumeNumber(4), kind: 'main' },
  isbn13: '9782226488190',
  coverUrl: 'https://covers.example/carl4.jpg',
} as never

beforeEach(() => {
  fake = resetFakeFirestore()
  asked.length = 0
  searchedAudible.length = 0
})

describe('a shown book’s page', () => {
  test('is described by the model and keeps the book the app named, spending no scan', async () => {
    const description = await DiscoveryUseCase.describeRelease(reader, volume, 'fr')

    expect(description).toMatchObject({
      book: {
        title: 'Carl 4',
        format: 'book',
        language: 'fr',
        synopsis: 'Carl descend au quatrième étage.',
        genre: 'fantasy',
        pageCount: 612,
        isbn13: '9782226488190',
        coverUrl: 'https://covers.example/carl4.jpg',
        series: { id: printed, volume: 4 },
      },
      narrators: [],
    })
    expect(asked).toHaveLength(1)
    expect(spent(reader)).toBe(0)
    expect(searchedAudible).toEqual([])
  })

  test('is described once for every reader: the next one reads it kept', async () => {
    await DiscoveryUseCase.describeRelease(reader, volume, 'fr')
    const [docReads, queryReads] = [fake.docReads, fake.queryReads]

    const description = await DiscoveryUseCase.describeRelease(other, volume, 'fr')

    expect(description).toMatchObject({ book: { synopsis: 'Carl descend au quatrième étage.' } })
    expect(asked).toHaveLength(1)
    expect(fake.docReads - docReads).toBe(1)
    expect(fake.queryReads - queryReads).toBe(0)
  })

  test('is described again in another language, and once sixty days have passed', async () => {
    await DiscoveryUseCase.describeRelease(reader, volume, 'fr')
    await DiscoveryUseCase.describeRelease(reader, volume, 'en')
    expect(asked).toHaveLength(2)

    const later = new Date(Date.now() + 61 * 86_400_000)
    await DiscoveryUseCase.describeRelease(reader, volume, 'fr', later)
    expect(asked).toHaveLength(3)
  })

  test('gives a recording Audible’s narrators and running time, and no pages', async () => {
    const description = await DiscoveryUseCase.describeRelease(
      reader,
      { title: 'Carl 4', authors: ['Matt Dinniman'], format: 'audiobook', language: 'fr' } as never,
      'fr',
    )

    expect(description).toMatchObject({
      book: {
        format: 'audiobook',
        publisher: 'Audible Studios',
        synopsis: 'Carl descend au quatrième étage.',
        coverUrl: 'https://m.media-amazon.com/carl4.jpg',
      },
      narrators: ['Jeff Hays'],
      durationMinutes: 1200,
    })
    expect((description as { book: { pageCount?: number } }).book.pageCount).toBeUndefined()
    expect(searchedAudible).toEqual(['Carl 4'])
  })

  test('is refused once the allowance is used up, unless someone described it already', async () => {
    fake.seed('ai-quotas', quotaDoc(reader), {
      userId: reader,
      month: monthOf(new Date()),
      scans: 5,
    })

    expect(await DiscoveryUseCase.describeRelease(reader, volume, 'fr')).toBe('quota-exhausted')
    expect(asked).toEqual([])

    await DiscoveryUseCase.describeRelease(other, volume, 'fr')
    expect(await DiscoveryUseCase.describeRelease(reader, volume, 'fr')).toMatchObject({
      book: { title: 'Carl 4' },
    })
  })
})
