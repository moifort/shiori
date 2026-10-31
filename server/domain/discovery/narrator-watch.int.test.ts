import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import { type FakeFirestore, fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/object-store', () => ({
  objectStore: () => ({ downloadUrl: async () => 'https://fake.store/cover' }),
}))
mock.module('~/system/apns', () => ({ Apns: { send: async () => 'sent' } }))

const narratorCalls: string[] = []
mock.module('~/domain/scan/gemini', () => ({
  generate: async ({ parts }: { parts: { text: string }[] }) => {
    const text = parts[0]?.text ?? ''
    const narrator = text.match(/suit le narrateur (.+?) en /)?.[1]
    if (narrator) narratorCalls.push(narrator)
    return {
      usage: { promptTokens: 1, outputTokens: 1, thinkingTokens: 0, searches: 4 },
      value: narrator
        ? {
            works: [
              { title: 'Fondation', authors: ['Isaac Asimov'], date: '2026-10-20' },
              { title: 'Terre et Fondation', authors: ['Isaac Asimov'], date: '2026-12-02' },
              { title: 'Déjà chez vous', authors: ['Isaac Asimov'], date: '2026-10-25' },
              { title: 'Trop ancien', authors: ['Isaac Asimov'], date: '2026-06-01' },
              { title: 'Sans date', authors: ['Isaac Asimov'] },
              { title: 'Sans auteur', authors: [], date: '2026-10-26' },
            ],
          }
        : { works: [], volumes: [] },
    }
  },
}))
mock.module('~/domain/discovery/infrastructure/audible-catalogue', () => ({
  audibleEditionOf: async () => 'unknown',
  audibleProductOf: async () => 'unknown',
  audibleSeriesOf: async () => 'unknown',
  audibleRecordingOf: async () => 'unknown',
}))
mock.module('~/domain/scan/bnf', () => ({ bnfEditionsOf: async () => [] }))

const { DiscoveryUseCase } = await import('~/domain/discovery/use-case')
const { DiscoveryQuery } = await import('~/domain/discovery/query')
const { NewsUseCase } = await import('~/domain/news/use-case')

const reader = 'reader' as UserId
const now = new Date('2026-10-31T08:00:00Z')
let fake: FakeFirestore

const recording = (id: string, title: string, narrators: string[], extra = {}) =>
  fake.seed('books', id, {
    id,
    userId: reader,
    title,
    authors: ['Isaac Asimov'],
    format: 'audiobook',
    media: [],
    subgenres: [],
    narrators,
    language: 'fr',
    status: 'read',
    hidden: false,
    addedAt: new Date('2026-01-01T00:00:00Z'),
    ...extra,
  })

beforeEach(() => {
  fake = resetFakeFirestore()
  narratorCalls.length = 0
  fake.seed('users', reader, { userId: reader, firstName: 'Bob' })
  // Two recordings of Bernard Gabay: followed. One of Kelly Marot, unrated: not.
  recording('a', 'Les Cavernes d’acier', ['Bernard Gabay'])
  recording('b', 'Face aux feux du soleil', ['Bernard Gabay'])
  recording('c', 'Déjà chez vous', ['Bernard Gabay'])
  recording('d', 'Circé', ['Kelly Marot'])
})

describe('the narrators’ watch', () => {
  test('looks a followed narrator up once, never one the reader barely heard', async () => {
    await DiscoveryUseCase.watchDueSagas(now)

    expect(narratorCalls).toEqual(['Bernard Gabay'])
  })

  test('looks them up again only after three months', async () => {
    await DiscoveryUseCase.watchDueSagas(now)
    narratorCalls.length = 0

    await DiscoveryUseCase.watchDueSagas(new Date('2026-12-15T08:00:00Z'))
    expect(narratorCalls).toEqual([])
    await DiscoveryUseCase.watchDueSagas(new Date('2027-02-01T08:00:00Z'))
    expect(narratorCalls).toEqual(['Bernard Gabay'])
  })

  test('keeps the works the web found, titled and authored, in a shared watch', async () => {
    await DiscoveryUseCase.watchDueSagas(now)

    const watches = await DiscoveryQuery.narratorWatches(['bernard-gabay--fr'])
    const titles = [...watches.values()].flatMap((watch) => watch.works.map((work) => work.title))
    expect(titles.map(String)).toContain('Fondation')
    expect(titles.map(String)).not.toContain('Sans auteur')
  })
})

describe('the narrators’ news', () => {
  test('tells the recordings out this month the reader does not hold, newest first', async () => {
    await DiscoveryUseCase.watchDueSagas(now)

    const news = await NewsUseCase.narratorNews(reader, now)

    expect(news.map((item) => String(item.title))).toEqual(['Fondation'])
    expect(news[0]?.narrator).toBe('Bernard Gabay' as never)
  })

  test('puts the ones still to come on the calendar, as recordings', async () => {
    await DiscoveryUseCase.watchDueSagas(now)

    const releases = await NewsUseCase.upcoming(reader, 'fr', undefined, now)

    const narrated = releases.filter((release) => release.source === 'narrator')
    expect(narrated.map((release) => String(release.title))).toEqual(['Terre et Fondation'])
    expect(narrated[0]).toMatchObject({ format: 'audiobook', narrator: 'Bernard Gabay' })
  })
})
