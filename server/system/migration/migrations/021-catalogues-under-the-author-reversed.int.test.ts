import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { cataloguesUnderTheAuthorReversed } = await import(
  '~/system/migration/migrations/021-catalogues-under-the-author-reversed'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const run = () => cataloguesUnderTheAuthorReversed.migrate({ db: fakeDb() })

const held = (seriesId: string) =>
  fake.seed('books', `book-${seriesId}`, {
    userId: 'r',
    title: 'Old Boy',
    language: 'fr',
    series: { id: seriesId, name: 'Old Boy', volume: 1, kind: 'main' },
  })

const catalogue = (key: string) =>
  fake.seed('series', key, { id: key.split('~')[0], name: 'Old Boy', author: 'A', volumes: [] })

describe('catalogues under the author reversed', () => {
  test('removes the catalogue nobody holds when its saga is held under the other order', async () => {
    held('old-boy--tsuchiya-garon')
    catalogue('old-boy--tsuchiya-garon~fr')
    catalogue('old-boy--garon-tsuchiya~fr')
    fake.seed('series-misses', 'old-boy--garon-tsuchiya~en', { id: 'old-boy--garon-tsuchiya' })

    expect(await run()).toEqual({ ok: true, transformed: 2 })

    expect(fake.data('series', 'old-boy--garon-tsuchiya~fr')).toBeNull()
    expect(fake.data('series-misses', 'old-boy--garon-tsuchiya~en')).toBeNull()
    expect(fake.data('series', 'old-boy--tsuchiya-garon~fr')).not.toBeNull()
  })

  test('keeps both when each order is held, and one held by nobody', async () => {
    held('old-boy--tsuchiya-garon')
    held('old-boy--garon-tsuchiya')
    catalogue('old-boy--tsuchiya-garon~fr')
    catalogue('old-boy--garon-tsuchiya~fr')
    catalogue('vagabond--inoue-takehiko~fr')

    expect(await run()).toEqual({ ok: true, transformed: 0 })
  })
})
