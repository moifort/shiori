import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { SeriesQuery } = await import('~/domain/series/query')
const { SeriesId } = await import('~/domain/series/primitives')

const dune = SeriesId('dune--frank-herbert')
const earthsea = SeriesId('earthsea--ursula-k-le-guin')
const missing = SeriesId('nobody--nobody')

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
  fake.seed('series', dune, { id: dune, name: 'Dune', volumes: [] })
  fake.seed('series', earthsea, { id: earthsea, name: 'Earthsea', volumes: [] })
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

    expect(found.map((entry) => entry.id)).toEqual([dune, earthsea])
    expect(fake.docReads - before).toBe(1)
  })
})
