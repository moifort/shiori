import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { SeriesQuery } = await import('~/domain/series/query')
const { SeriesId } = await import('~/domain/series/primitives')

const dune = { id: SeriesId('dune--frank-herbert'), language: 'fr' as const }
const earthsea = { id: SeriesId('earthsea--ursula-k-le-guin'), language: 'en' as const }
const missing = { id: SeriesId('nobody--nobody'), language: 'fr' as const }

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
  fake.seed('series', `${dune.id}~fr`, { ...dune, name: 'Dune', volumes: [] })
  fake.seed('series', `${earthsea.id}~en`, { ...earthsea, name: 'Earthsea', volumes: [] })
})

describe('reading catalogues in one request', () => {
  test('answers a saga the tab already fetched without reading it again', async () => {
    await SeriesQuery.byIds([dune, earthsea, missing])
    const before = fake.docReads

    expect(await SeriesQuery.byId(dune)).toMatchObject({ name: 'Dune' })
    expect(await SeriesQuery.byId(missing)).toBeNull()
    expect(fake.docReads).toBe(before)
  })

  test('fetches only the sagas not yet read', async () => {
    await SeriesQuery.byId(dune)
    const before = fake.docReads

    const found = await SeriesQuery.byIds([dune, earthsea, dune])

    expect(found.map((entry) => entry.id)).toEqual([dune.id, earthsea.id])
    expect(fake.docReads - before).toBe(1)
  })
})

describe('one catalogue per edition', () => {
  test('the same saga in another language is another catalogue', async () => {
    expect(await SeriesQuery.byId({ ...dune, language: 'en' })).toBeNull()
    expect(await SeriesQuery.byId(dune)).toMatchObject({ name: 'Dune', language: 'fr' })
  })
})
