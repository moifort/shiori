import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { graphql } from 'graphql'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'
import { GOODREADS_EXPORT } from '~/test/goodreads-export'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/object-store', () => ({
  objectStore: () => ({ downloadUrl: async () => 'https://fake.store/cover' }),
}))

const { schema } = await import('~/domain/shared/graphql/schema')

const userId = 'reader-1' as UserId

beforeEach(() => {
  resetFakeFirestore()
})

const execute = (source: string, variableValues?: Record<string, unknown>) =>
  graphql({ schema, source, contextValue: { event: {}, userId }, variableValues })

const PREVIEW = `mutation Preview($csv: String!) {
  previewGoodreadsExport(csv: $csv) {
    rows { key title authors series { name volume } shelf dropped verdict rating hasReview coverUrl }
    shelves { read reading toRead dropped }
    rated dated reviewed
  }
}`

const IMPORT = `mutation Import($csv: String!, $choices: GoodreadsChoicesInput!) {
  importGoodreadsExport(csv: $csv, choices: $choices) { imported completed wished pendingCovers }
}`

describe('previewing a Goodreads export', () => {
  test('answers its books and their shelves', async () => {
    const result = await execute(PREVIEW, { csv: GOODREADS_EXPORT })

    expect(result.errors).toBeUndefined()
    const preview = result.data?.previewGoodreadsExport as {
      rows: { title: string; series: { name: string; volume: number } | null; verdict: string }[]
      shelves: Record<string, number>
    }
    expect(preview.rows).toHaveLength(5)
    expect(preview.rows[0]).toMatchObject({
      title: 'The Way of Kings',
      series: { name: 'The Stormlight Archive', volume: 1 },
      verdict: 'NEW',
    })
    expect(preview.shelves).toEqual({ read: 2, reading: 1, toRead: 1, dropped: 1 })
  })

  test('refuses a file that is not a Goodreads export', async () => {
    const result = await execute(PREVIEW, { csv: 'Title,Author\nDune,Frank Herbert' })

    expect(result.errors?.[0]?.extensions?.code).toBe('GOODREADS_NOT_AN_EXPORT')
  })
})

describe('importing a Goodreads export', () => {
  test('catalogues the ticked rows and answers what it wrote', async () => {
    const preview = await execute(PREVIEW, { csv: GOODREADS_EXPORT })
    const keys = (preview.data?.previewGoodreadsExport as { rows: { key: string }[] }).rows.map(
      (row) => row.key,
    )

    const result = await execute(IMPORT, {
      csv: GOODREADS_EXPORT,
      choices: {
        keys,
        toRead: 'WISHLIST',
        keepRatings: true,
        keepDates: true,
        keepReviews: true,
        sameBooks: [],
      },
    })

    expect(result.errors).toBeUndefined()
    expect(result.data?.importGoodreadsExport).toEqual({
      imported: 4,
      completed: 0,
      wished: 1,
      pendingCovers: 2,
    })
    const last = await execute('{ goodreadsImport { imported wished pendingCovers } }')
    expect(last.data?.goodreadsImport).toEqual({ imported: 4, wished: 1, pendingCovers: 2 })
  })

  test('answers null for a reader who never imported', async () => {
    const result = await execute('{ goodreadsImport { imported } }')

    expect(result.errors).toBeUndefined()
    expect(result.data?.goodreadsImport).toBeNull()
  })
})
