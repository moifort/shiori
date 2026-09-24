import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { graphql } from 'graphql'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/object-store', () => ({
  objectStore: () => ({ downloadUrl: async () => 'https://fake.store/cover' }),
}))

const { schema } = await import('~/domain/shared/graphql/schema')

const bob = 'bob' as UserId
const run = (source: string, variableValues?: Record<string, unknown>) =>
  graphql({ schema, source, contextValue: { event: {}, userId: bob }, variableValues })

beforeEach(() => {
  resetFakeFirestore()
})

describe('the Découvrir tab', () => {
  test('starts unprepared and empty', async () => {
    const result = await run(
      '{ discover { preparedAt canRefresh upcoming { key } available { key title editions { format date audibleUrl } } } }',
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.discover).toEqual({
      preparedAt: null,
      canRefresh: true,
      upcoming: [],
      available: [],
    })
  })

  test('dismisses nothing before the tab was ever opened', async () => {
    const result = await run('mutation { dismissTranslation(key: "book--a--b") }')

    expect(result.data?.dismissTranslation).toBe(false)
  })

  test('remembers a work the reader is not interested in', async () => {
    await run('{ discover { canRefresh } }')

    const result = await run('mutation { dismissTranslation(key: "book--a--b") }')

    expect(result.data?.dismissTranslation).toBe(true)
  })
})
