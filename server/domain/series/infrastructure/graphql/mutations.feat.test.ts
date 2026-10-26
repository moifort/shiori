import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { graphql } from 'graphql'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/object-store', () => ({
  objectStore: () => ({ downloadUrl: async () => 'https://fake.store/cover' }),
}))

const { schema } = await import('~/domain/shared/graphql/schema')

const userId = 'reader-1' as UserId
let fake: ReturnType<typeof resetFakeFirestore>

beforeEach(() => {
  fake = resetFakeFirestore()
})

const execute = (source: string) => graphql({ schema, source, contextValue: { event: {}, userId } })

const holdDune = async () => {
  fake.seed('series', 'dune--frank-herbert~fr', {
    id: 'dune--frank-herbert~fr',
    saga: 'dune--frank-herbert',
    language: 'fr',
    name: 'Dune (French Edition)',
    author: 'Frank Herbert',
    description: 'Une saga de pirates.',
    volumes: [{ number: 1, title: 'Dune', kind: 'main' }],
    catalogedAt: new Date('2026-10-01'),
  })
  await execute(
    `mutation { addBook(input: {
      title: "Dune"
      authors: ["Frank Herbert"]
      language: FR
      series: { id: "dune--frank-herbert", name: "Dune (French Edition)", volume: 1, kind: MAIN }
    }) { id } }`,
  )
}

describe('correctSeries', () => {
  test('answers the edition as the saga screen draws it', async () => {
    await holdDune()

    const result = await execute(
      `mutation { correctSeries(seriesId: "dune--frank-herbert~fr", name: "Dune", format: MANGA, description: null) {
        name description
      } }`,
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.correctSeries).toEqual({ name: 'Dune', description: null })
    const shelf = await execute(
      `{ mySeriesVolumes(seriesId: "dune--frank-herbert~fr") { format series { name } } }`,
    )
    expect(shelf.data?.mySeriesVolumes).toEqual([{ format: 'MANGA', series: { name: 'Dune' } }])
  })

  test('refuses a recording', async () => {
    await holdDune()

    const result = await execute(
      `mutation { correctSeries(seriesId: "dune--frank-herbert~fr", format: AUDIOBOOK) { name } }`,
    )

    expect(result.errors?.[0].extensions?.code).toBe('BAD_USER_INPUT')
  })

  test('is not found for an edition the reader holds nothing of', async () => {
    const result = await execute(
      `mutation { correctSeries(seriesId: "dune--frank-herbert~fr", name: "Dune") { name } }`,
    )

    expect(result.errors?.[0].extensions?.code).toBe('NOT_FOUND')
  })
})
