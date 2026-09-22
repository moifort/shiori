import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { graphql } from 'graphql'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/object-store', () => ({
  objectStore: () => ({
    downloadUrl: async () => 'https://fake.store/cover',
    removeByPrefix: async () => undefined,
  }),
}))
mock.module('~/system/identity', () => ({ deleteAuthUser: async () => undefined }))

const { schema } = await import('~/domain/shared/graphql/schema')

const alice = 'alice' as UserId
const bob = 'bob' as UserId
const carol = 'carol' as UserId

beforeEach(() => {
  resetFakeFirestore()
})

const as = (userId: UserId) => (source: string, variableValues?: Record<string, unknown>) =>
  graphql({ schema, source, contextValue: { event: {}, userId }, variableValues })

/** Alice invites, Bob accepts: the friendship every test below starts from. */
const befriend = async () => {
  const invitation = await as(alice)('mutation { inviteFriend { code } }')
  expect(invitation.errors).toBeUndefined()
  const { code } = (invitation.data as { inviteFriend: { code: string } }).inviteFriend
  const accepted = await as(bob)(
    'mutation Accept($code: String!) { acceptFriendInvitation(code: $code) { userId } }',
    { code },
  )
  expect(accepted.errors).toBeUndefined()
  return code
}

describe('inviting somebody to share libraries', () => {
  // Every extra code is another key to the reader's library outstanding.
  test('answers the invitation already standing rather than making another', async () => {
    const first = await as(alice)('mutation { inviteFriend { code } }')
    const again = await as(alice)('mutation { inviteFriend { code } }')

    expect(again.data).toEqual(first.data)
  })

  test('opens both libraries at once, with no second acceptance to make', async () => {
    await befriend()

    const hers = await as(alice)('{ friends { userId } }')
    const his = await as(bob)('{ friends { userId } }')

    expect(hers.data?.friends).toEqual([{ userId: 'bob' }])
    expect(his.data?.friends).toEqual([{ userId: 'alice' }])
  })

  // A link reaches more people than intended. The code opened the library it
  // was meant to open, and that is the end of it.
  test('spends the code, so the same link opens nothing twice', async () => {
    const code = await befriend()

    const third = await as(carol)(
      'mutation Accept($code: String!) { acceptFriendInvitation(code: $code) { userId } }',
      { code },
    )

    expect(third.errors?.[0]?.extensions?.code).toBe('NOT_FOUND')
    expect((await as(carol)('{ friends { userId } }')).data?.friends).toEqual([])
  })

  test('refuses a code that names nothing, and the reader own invitation', async () => {
    const mine = await as(alice)('mutation { inviteFriend { code } }')
    const { code } = (mine.data as { inviteFriend: { code: string } }).inviteFriend

    const nothing = await as(bob)(
      'mutation Accept($code: String!) { acceptFriendInvitation(code: $code) { userId } }',
      { code: 'ZZZZZZZZ' },
    )
    const own = await as(alice)(
      'mutation Accept($code: String!) { acceptFriendInvitation(code: $code) { userId } }',
      { code },
    )

    expect(nothing.errors?.[0]?.extensions?.code).toBe('NOT_FOUND')
    expect(own.errors?.[0]?.extensions?.code).toBe('BAD_USER_INPUT')
  })

  // The app hands over whatever the reader pasted: the link, or the code with a
  // stray space, or the code in lower case.
  test('takes the code out of the link that carries it', async () => {
    const mine = await as(alice)('mutation { inviteFriend { code } }')
    const { code } = (mine.data as { inviteFriend: { code: string } }).inviteFriend

    const accepted = await as(bob)(
      'mutation Accept($code: String!) { acceptFriendInvitation(code: $code) { userId } }',
      { code: ` https://shiori.app/invite/${code.toLowerCase()} ` },
    )

    expect(accepted.errors).toBeUndefined()
    expect(accepted.data?.acceptFriendInvitation).toEqual({ userId: 'alice' })
  })

  test('ends for both when either one ends it', async () => {
    await befriend()

    const removed = await as(bob)(
      'mutation Remove($userId: UserId!) { removeFriend(userId: $userId) }',
      { userId: 'alice' },
    )

    expect(removed.data?.removeFriend).toBe(true)
    expect((await as(alice)('{ friends { userId } }')).data?.friends).toEqual([])
    expect((await as(bob)('{ friends { userId } }')).data?.friends).toEqual([])
  })
})

describe('reading a friend shelf', () => {
  const addBook = (owner: UserId, fields: string) =>
    as(owner)(`mutation { addBook(input: { ${fields} }) { id } }`)

  test('shows what they are reading, their pile, their favourites and their sagas', async () => {
    const reading = await addBook(alice, 'title: "Dune", status: READING')
    const pile = await addBook(
      alice,
      'title: "Hypérion", authors: ["Dan Simmons"], series: { id: "hyperion--dan-simmons", name: "Hypérion", volume: 1, kind: MAIN }',
    )
    // A heart is five stars, which marks a book read: the favourite is one
    // off the pile.
    const loved = await addBook(alice, 'title: "Fondation", status: READ')
    expect(reading.errors).toBeUndefined()
    expect(pile.errors).toBeUndefined()
    const lovedId = (loved.data as { addBook: { id: string } }).addBook.id
    await as(alice)(`mutation { setBookFavorite(id: "${lovedId}", favorite: true) { id } }`)
    await befriend()

    const result = await as(bob)(
      '{ friendProfile(userId: "alice") { firstName reading { title } pile { title favorite } favorites { title } sagas { name ownedCount } } }',
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.friendProfile).toEqual({
      firstName: null,
      reading: [{ title: 'Dune' }],
      pile: [{ title: 'Hypérion', favorite: false }],
      favorites: [{ title: 'Fondation' }],
      sagas: [{ name: 'Hypérion', ownedCount: 1 }],
    })
  })

  // The flag was built in batch 1 for exactly this moment.
  test('leaves out a book its owner marked "do not share"', async () => {
    const kept = await addBook(alice, 'title: "Dune", status: READING')
    const secret = await addBook(alice, 'title: "Un secret", status: READING')
    const secretId = (secret.data as { addBook: { id: string } }).addBook.id
    expect(kept.errors).toBeUndefined()
    await as(alice)(`mutation { setBookHidden(id: "${secretId}", hidden: true) { id } }`)
    await befriend()

    const result = await as(bob)('{ friendProfile(userId: "alice") { reading { title } } }')

    expect(result.data?.friendProfile).toEqual({ reading: [{ title: 'Dune' }] })
  })

  // A friend sees a shelf, not a diary. There is no field for the note at all,
  // which is what makes this permanent rather than a rule somebody must follow.
  test('has no field through which a reading note could be read', async () => {
    await befriend()

    const result = await as(bob)('{ friendProfile(userId: "alice") { reading { note } } }')

    expect(result.errors?.[0]?.message).toContain('note')
  })

  // A stranger must not be able to tell an account that refused them from one
  // that does not exist.
  test('answers nothing for a stranger and for an id that names nobody', async () => {
    await addBook(alice, 'title: "Dune", status: READING')

    const stranger = await as(carol)('{ friendProfile(userId: "alice") { reading { title } } }')
    const nobody = await as(carol)('{ friendProfile(userId: "nobody") { reading { title } } }')

    expect(stranger.errors).toBeUndefined()
    expect(stranger.data?.friendProfile).toBeNull()
    expect(nobody.data?.friendProfile).toBeNull()
  })

  test('closes again the moment the friendship ends', async () => {
    await addBook(alice, 'title: "Dune", status: READING')
    await befriend()

    await as(alice)('mutation Remove($userId: UserId!) { removeFriend(userId: $userId) }', {
      userId: 'bob',
    })

    const result = await as(bob)('{ friendProfile(userId: "alice") { reading { title } } }')
    expect(result.data?.friendProfile).toBeNull()
  })
})

describe('deleting an account', () => {
  test('takes its friendships with it', async () => {
    await befriend()

    const deleted = await as(alice)('mutation { deleteAccount }')

    expect(deleted.errors).toBeUndefined()
    expect((await as(bob)('{ friends { userId } }')).data?.friends).toEqual([])
  })
})
