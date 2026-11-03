import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { graphql } from 'graphql'
import type { UserId } from '~/domain/shared/types'
import { type FakeFirestore, fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/object-store', () => ({
  objectStore: () => ({
    downloadUrl: async () => 'https://fake.store/cover',
    removeByPrefix: async () => undefined,
  }),
}))
mock.module('~/system/identity', () => ({ deleteAuthUser: async () => undefined }))

const { schema } = await import('~/domain/shared/graphql/schema')
const { BookUseCase } = await import('~/domain/book/use-case')
const { AuthorName, BookTitle } = await import('~/domain/shared/primitives')

const alice = 'alice' as UserId
const bob = 'bob' as UserId

let fake: FakeFirestore

beforeEach(() => {
  fake = resetFakeFirestore()
})

const as = (userId: UserId) => (source: string, variableValues?: Record<string, unknown>) =>
  graphql({ schema, source, contextValue: { event: {}, userId }, variableValues })

const WISH = 'id title authors format origin originLabel friendId coverUrl'

const piranesi = {
  title: 'Piranesi',
  authors: ['Susanna Clarke'],
  format: 'BOOK',
  language: 'EN',
  coverUrl: 'https://covers.example/piranesi.jpg',
}

const wishBook = (userId: UserId, book = piranesi, origin = 'DISCOVERY', label?: string) =>
  as(userId)(
    `mutation ($book: WishedBookInput!, $origin: WishOrigin!, $label: String) {
      wishBook(book: $book, origin: $origin, originLabel: $label) { ${WISH} }
    }`,
    { book, origin, label },
  )

const wishlist = async (userId: UserId) => {
  const result = await as(userId)(`{ wishlist { wishes { ${WISH} } awaited { id } } }`)
  expect(result.errors).toBeUndefined()
  return (result.data as { wishlist: { wishes: { title: string; origin: string }[] } }).wishlist
}

const shelve = (userId: UserId, title: string, author: string) =>
  BookUseCase.add(userId, {
    title: BookTitle(title),
    authors: [AuthorName(author)],
    status: 'to-read',
    language: 'en',
    format: 'book',
  })

/** Alice invites, Bob accepts. */
const befriend = async () => {
  const invitation = await as(alice)('mutation { inviteFriend { code } }')
  const { code } = (invitation.data as { inviteFriend: { code: string } }).inviteFriend
  await as(bob)(
    'mutation Accept($code: String!) { acceptFriendInvitation(code: $code) { userId } }',
    { code },
  )
}

describe('wishing for a book', () => {
  test('keeps a discovery on the wishlist with where it came from', async () => {
    const wished = await wishBook(bob)
    expect(wished.errors).toBeUndefined()

    expect((await wishlist(bob)).wishes).toEqual([
      expect.objectContaining({ title: 'Piranesi', origin: 'DISCOVERY', originLabel: null }),
    ])
  })

  test('answers a second wish for the same story with the first', async () => {
    await wishBook(bob, piranesi, 'DISCOVERY')
    const again = await wishBook(bob, { ...piranesi, format: 'AUDIOBOOK' }, 'AWARD', 'Hugo')

    expect(again.data).toEqual({
      wishBook: expect.objectContaining({ origin: 'DISCOVERY', format: 'BOOK' }),
    })
    expect((await wishlist(bob)).wishes).toHaveLength(1)
  })

  test('refuses a story the library holds', async () => {
    await shelve(bob, 'Piranesi', 'Susanna Clarke')

    const wished = await wishBook(bob)

    expect(wished.errors?.[0]?.extensions?.code).toBe('ALREADY_IN_LIBRARY')
  })

  test('refuses the friend origin, which goes through wishFriendBook', async () => {
    const wished = await wishBook(bob, piranesi, 'FRIEND')

    expect(wished.errors?.[0]?.extensions?.code).toBe('BAD_USER_INPUT')
  })

  test('lets the wish go once the library holds the story', async () => {
    await wishBook(bob)
    await shelve(bob, 'Piranesi', 'Susanna Clarke')

    expect((await wishlist(bob)).wishes).toEqual([])
    expect(fake.snapshot('wishes').size).toBe(0)
  })

  test('drops a wish, and only the reader’s own', async () => {
    const wished = await wishBook(bob)
    const { id } = (wished.data as { wishBook: { id: string } }).wishBook
    const remove = 'mutation ($id: WishId!) { removeWish(id: $id) }'

    expect((await as(alice)(remove, { id })).data).toEqual({ removeWish: false })
    expect((await as(bob)(remove, { id })).data).toEqual({ removeWish: true })
    expect((await wishlist(bob)).wishes).toEqual([])
  })
})

describe('wishing for a friend’s book', () => {
  test('re-reads the book and names the friend, never their photo', async () => {
    await befriend()
    fake.seed('users', alice, { userId: alice, firstName: 'Alice' })
    const book = await BookUseCase.add(alice, {
      title: BookTitle('Le Grand Méchant Renard'),
      authors: [AuthorName('Benjamin Renner')],
      status: 'read',
      language: 'fr',
      format: 'bande-dessinee',
    })

    const wished = await as(bob)(
      `mutation ($userId: UserId!, $bookId: BookId!) { wishFriendBook(userId: $userId, bookId: $bookId) { ${WISH} } }`,
      { userId: alice, bookId: book.id },
    )

    expect(wished.errors).toBeUndefined()
    expect(wished.data).toEqual({
      wishFriendBook: expect.objectContaining({
        title: 'Le Grand Méchant Renard',
        origin: 'FRIEND',
        originLabel: 'Alice',
        friendId: alice,
        coverUrl: null,
      }),
    })
  })

  test('refuses a stranger’s book', async () => {
    const book = await shelve(alice, 'Piranesi', 'Susanna Clarke')

    const wished = await as(bob)(
      `mutation ($userId: UserId!, $bookId: BookId!) { wishFriendBook(userId: $userId, bookId: $bookId) { id } }`,
      { userId: alice, bookId: book.id },
    )

    expect(wished.errors?.[0]?.extensions?.code).toBe('NOT_FOUND')
  })
})

describe('deleting an account', () => {
  test('takes its wishes with it', async () => {
    await wishBook(bob)

    await as(bob)('mutation { deleteAccount }')

    expect(fake.snapshot('wishes').size).toBe(0)
  })
})
