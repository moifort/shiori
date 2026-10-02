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

/** Audible sells the fourth recording, read by Jeff Hays. */
mock.module('~/domain/discovery/infrastructure/audible-catalogue', () => ({
  audibleEditionOf: async () => 'unknown',
  audibleProductOf: async () => 'unknown',
  audibleSeriesOf: async () => 'unknown',
  audibleRecordingOf: async (asin: string) =>
    asin === 'B0DM67WR2V'
      ? {
          title: 'Dungeon Crawler Carl 4',
          authors: ['Matt Dinniman'],
          narrators: ['Jeff Hays'],
          publisher: 'Audible Studios',
          synopsis: 'Le livre audio événement !',
          durationMinutes: 1200,
          coverUrl: 'https://m.media-amazon.com/carl4.jpg',
        }
      : 'unknown',
}))

const { DiscoveryUseCase } = await import('~/domain/discovery/use-case')
const { monthOf } = await import('~/domain/quota/business-rules')
const { VolumeNumber, seriesKeyOf } = await import('~/domain/series/primitives')

const reader = 'reader' as UserId
const printed = seriesKeyOf('Dungeon Crawler Carl', 'Matt Dinniman', 'book')
const heard = seriesKeyOf('Dungeon Crawler Carl', 'Matt Dinniman', 'audiobook')
let fake: FakeFirestore

const quotaDoc = () => `${reader}_${monthOf(new Date())}`
const spent = () => (fake.data('ai-quotas', quotaDoc()) as { scans: number } | null)?.scans ?? 0

const watch = (seriesId: string, volume: Record<string, unknown>) =>
  fake.seed('saga-watches', `${seriesId}--fr`, {
    key: `${seriesId}--fr`,
    seriesId,
    name: 'Dungeon Crawler Carl',
    author: 'Matt Dinniman',
    language: 'fr',
    checkedAt: new Date(),
    volumes: [volume],
  })

beforeEach(() => {
  fake = resetFakeFirestore()
  asked.length = 0
})

describe('an announced volume’s page', () => {
  test('describes a printed volume with the model, and spends one scan', async () => {
    watch(printed, { number: 4, title: 'Carl 4', date: '2027-02-12', isbn13: '9782226488190' })

    const preview = await DiscoveryUseCase.previewAnnouncedVolume(
      reader,
      { seriesId: printed, language: 'fr', number: VolumeNumber(4) },
      'fr',
    )

    expect(preview).toMatchObject({
      book: {
        title: 'Carl 4',
        authors: ['Matt Dinniman'],
        format: 'book',
        language: 'fr',
        synopsis: 'Carl descend au quatrième étage.',
        genre: 'fantasy',
        pageCount: 612,
        isbn13: '9782226488190',
        series: { id: printed, volume: 4, kind: 'main' },
      },
      releaseDate: '2027-02-12',
      narrators: [],
    })
    expect(asked).toHaveLength(1)
    expect(asked[0]).toContain('« Carl 4 » de Matt Dinniman')
    expect(spent()).toBe(1)
  })

  test('reads a recording off Audible first, and the model improves on it', async () => {
    watch(heard, { number: 4, title: 'Carl 4', date: '2027-02-12', asin: 'B0DM67WR2V' })

    const preview = await DiscoveryUseCase.previewAnnouncedVolume(
      reader,
      { seriesId: heard, language: 'fr', number: VolumeNumber(4) },
      'fr',
    )

    expect(preview).toMatchObject({
      book: {
        title: 'Dungeon Crawler Carl 4',
        format: 'audiobook',
        publisher: 'Audible Studios',
        synopsis: 'Carl descend au quatrième étage.',
        genre: 'fantasy',
        coverUrl: 'https://m.media-amazon.com/carl4.jpg',
      },
      narrators: ['Jeff Hays'],
      durationMinutes: 1200,
      asin: 'B0DM67WR2V',
    })
    // The model is told the edition Audible sells, publisher included.
    expect(asked[0]).toContain('« Dungeon Crawler Carl 4 »')
    expect(asked[0]).toContain('Audible Studios')
    expect(spent()).toBe(1)
  })

  test('refuses a volume no watch announced, and spends nothing', async () => {
    watch(printed, { number: 4, title: 'Carl 4', date: '2027-02-12' })

    const preview = await DiscoveryUseCase.previewAnnouncedVolume(
      reader,
      { seriesId: printed, language: 'fr', number: VolumeNumber(9) },
      'fr',
    )

    expect(preview).toBe('not-found')
    expect(asked).toEqual([])
    expect(spent()).toBe(0)
  })

  test('is refused once the allowance is used up', async () => {
    watch(printed, { number: 4, title: 'Carl 4', date: '2027-02-12' })
    fake.seed('ai-quotas', quotaDoc(), { userId: reader, month: monthOf(new Date()), scans: 5 })

    const preview = await DiscoveryUseCase.previewAnnouncedVolume(
      reader,
      { seriesId: printed, language: 'fr', number: VolumeNumber(4) },
      'fr',
    )

    expect(preview).toBe('quota-exhausted')
    expect(asked).toEqual([])
  })
})
