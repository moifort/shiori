import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { graphql } from 'graphql'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/config', () => ({
  config: () => ({ googleApiKey: 'test-key', premiumUserIds: [] }),
}))

let answers: unknown[] = []
mock.module('~/domain/scan/gemini', () => ({
  generate: async ({ step }: { step: string }) => {
    const value = answers.shift()
    if (value === undefined) throw new Error(`no queued answer for step "${step}"`)
    if (value instanceof Error) throw value
    return { value, usage: { promptTokens: 10, outputTokens: 5, thinkingTokens: 0, searches: 0 } }
  },
}))

const { schema } = await import('~/domain/shared/graphql/schema')
const { monthOf } = await import('~/domain/quota/business-rules')

const userId = 'reader-1' as UserId
let fake: ReturnType<typeof resetFakeFirestore>

beforeEach(() => {
  fake = resetFakeFirestore()
  answers = []
})

const searchTitle = (title: string) =>
  graphql({
    schema,
    source: `mutation($title: BookTitle!) {
      searchTitle(title: $title) { title authors firstPublishedIn seriesName volume }
    }`,
    variableValues: { title },
    // No event: the language then falls back to the default rather than reading
    // a header off a request there is none of.
    contextValue: { event: undefined, userId },
  })

describe('searchTitle', () => {
  test('answers the books a typed title may mean', async () => {
    answers = [
      {
        candidates: [
          {
            title: 'Fondation',
            authors: ['Isaac Asimov'],
            firstPublishedIn: 1951,
            seriesName: 'Fondation',
            volumeNumber: 1,
          },
          { title: 'Fondation et Empire', authors: ['Isaac Asimov'] },
        ],
      },
    ]

    const result = await searchTitle('fondation')

    expect(result.errors).toBeUndefined()
    expect(result.data).toEqual({
      searchTitle: [
        {
          title: 'Fondation',
          authors: ['Isaac Asimov'],
          firstPublishedIn: 1951,
          seriesName: 'Fondation',
          volume: 1,
        },
        {
          title: 'Fondation et Empire',
          authors: ['Isaac Asimov'],
          firstPublishedIn: null,
          seriesName: null,
          volume: null,
        },
      ],
    })
  })

  test('is refused with QUOTA_EXHAUSTED once the allowance is used up', async () => {
    fake.seed('ai-quotas', `${userId}_${monthOf(new Date())}`, {
      userId,
      month: monthOf(new Date()),
      scans: 5,
    })

    const result = await searchTitle('Dune')

    expect(result.errors?.[0]?.extensions?.code).toBe('QUOTA_EXHAUSTED')
  })

  test('fails with SCAN_FAILED when the model errors', async () => {
    answers = [new Error('model unavailable')]

    const result = await searchTitle('Dune')

    expect(result.errors?.[0]?.extensions?.code).toBe('SCAN_FAILED')
  })
})
