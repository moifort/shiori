import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { parse } from 'graphql'
import type { UserId } from '~/domain/shared/types'

const stamped: UserId[][] = []
mock.module('~/domain/discovery/command', () => ({
  DiscoveryCommand: {
    recordLibraryChange: async (userIds: UserId[]) => {
      stamped.push(userIds)
    },
  },
}))

const { discoveryProjectionInvalidation } = await import('./projection-invalidation')

const userId = 'bob' as UserId

/** The plugin's answer hook run on one operation, as Apollo would. */
const answered = async (source: string, contextUserId: UserId | undefined = userId) => {
  const operation = parse(source).definitions[0]
  const listener = await discoveryProjectionInvalidation.requestDidStart?.({} as never)
  await listener?.willSendResponse?.({
    operation,
    contextValue: { userId: contextUserId },
  } as never)
}

beforeEach(() => {
  stamped.length = 0
})

describe('the Découvrir projection after a mutation', () => {
  test('goes stale after a mutation of the library', async () => {
    await answered('mutation { rateBook(id: "1", rating: 5) { id } }')

    expect(stamped).toEqual([[userId]])
  })

  test('goes stale when a mutation mixes a library change with one that leaves it alone', async () => {
    await answered('mutation { registerDevice(token: "t") deleteBook(id: "1") }')

    expect(stamped).toEqual([[userId]])
  })

  test('stays fresh after a query, a mutation that leaves it alone, or the account deleted', async () => {
    await answered('query { dashboard { total } }')
    await answered('mutation { registerDevice(token: "t") }')
    await answered('mutation { deleteAccount }')
    await answered('mutation { lookUpDiscovery(format: BOOK) { unwatched } }')

    expect(stamped).toEqual([])
  })

  test('marks nothing without a reader', async () => {
    await answered('mutation { rateBook(id: "1", rating: 5) { id } }', '' as UserId)

    expect(stamped).toEqual([])
  })
})
