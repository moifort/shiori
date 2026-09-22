import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { graphql } from 'graphql'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/object-store', () => ({
  objectStore: () => ({ downloadUrl: async () => 'https://fake.store/cover' }),
}))

const { schema } = await import('~/domain/shared/graphql/schema')

const alice = 'alice' as UserId
const bob = 'bob' as UserId
const as = (userId: UserId) => (source: string, variableValues?: Record<string, unknown>) =>
  graphql({ schema, source, contextValue: { event: {}, userId }, variableValues })

const befriend = async () => {
  const invitation = await as(alice)('mutation { inviteFriend { code } }')
  const { code } = (invitation.data as { inviteFriend: { code: string } }).inviteFriend
  await as(bob)('mutation A($code: String!) { acceptFriendInvitation(code: $code) { userId } }', {
    code,
  })
}

const heart = async (owner: UserId, fields: string) => {
  const added = await as(owner)(`mutation { addBook(input: { ${fields}, status: READ }) { id } }`)
  const id = (added.data as { addBook: { id: string } }).addBook.id
  await as(owner)(`mutation { setBookFavorite(id: "${id}", favorite: true) { id } }`)
  return id
}

beforeEach(() => {
  resetFakeFirestore()
})

describe('the Découvrir tab', () => {
  test('starts unprepared, with the hearts of friends the reader does not own', async () => {
    await as(alice)('mutation { completeOnboarding(input: { firstName: "Alice" }) { firstName } }')
    const piranesi = await heart(alice, 'title: "Piranesi", authors: ["Susanna Clarke"]')
    await heart(alice, 'title: "Dune", authors: ["Frank Herbert"]')
    await as(bob)(
      'mutation { addBook(input: { title: "Dune", authors: ["Frank Herbert"] }) { id } }',
    )
    await befriend()

    const result = await as(bob)(
      '{ discover { preparedAt canRefresh friendsFavorites { title friendNames friendId bookId } offTrail { title } } }',
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.discover).toEqual({
      preparedAt: null,
      canRefresh: true,
      friendsFavorites: [
        { title: 'Piranesi', friendNames: ['Alice'], friendId: 'alice', bookId: piranesi },
      ],
      offTrail: [],
    })
  })

  test('leaves out a friend heart marked "do not share"', async () => {
    const secret = await heart(alice, 'title: "Un secret", authors: ["Alice"]')
    await as(alice)(`mutation { setBookHidden(id: "${secret}", hidden: true) { id } }`)
    await befriend()

    const result = await as(bob)('{ discover { friendsFavorites { title } } }')

    expect(result.data?.discover).toEqual({ friendsFavorites: [] })
  })

  test('refuses to add a suggestion it does not hold', async () => {
    await as(bob)('{ discover { canRefresh } }')

    const result = await as(bob)(
      'mutation { addSuggestion(key: "nothing--nobody", status: TO_READ) { id } }',
    )

    expect(result.errors?.[0]?.extensions?.code).toBe('NOT_FOUND')
  })

  test('dismisses nothing before the tab was ever opened', async () => {
    const result = await as(bob)('mutation { dismissSuggestion(key: "a--b") }')

    expect(result.data?.dismissSuggestion).toBe(false)
  })
})
