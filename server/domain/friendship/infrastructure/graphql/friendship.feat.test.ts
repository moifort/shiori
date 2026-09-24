import { afterEach, beforeEach, describe, expect, mock, setSystemTime, test } from 'bun:test'
import { graphql } from 'graphql'
import type { UserId } from '~/domain/shared/types'
import {
  type FakeFirestore,
  fakeDb,
  resetFakeFirestore,
  startFakeRequest,
} from '~/test/fake-firestore'

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

let fake: FakeFirestore

beforeEach(() => {
  fake = resetFakeFirestore()
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

describe("the reader's own shelf, as friends see it", () => {
  // A test that freezes the clock hands the real one back to the next.
  afterEach(() => {
    setSystemTime()
  })

  const addBook = async (owner: UserId, fields: string) => {
    const result = await as(owner)(`mutation { addBook(input: { ${fields} }) { id } }`)
    expect(result.errors).toBeUndefined()
    return (result.data as { addBook: { id: string } }).addBook.id
  }
  const dune = (volume: number) =>
    `title: "Dune ${volume}", authors: ["Frank Herbert"], genre: SCIENCE_FICTION, status: READ, series: { id: "dune--frank-herbert", name: "Dune", volume: ${volume}, kind: MAIN }, coverUrl: "https://covers.example/dune-${volume}.jpg"`

  // A hearted saga stands for its volumes: listing one again among the
  // favourite books would carry it twice into a list shared with somebody.
  test('lists a hearted volume under its hearted saga, never again on its own', async () => {
    const first = await addBook(alice, dune(1))
    await addBook(alice, dune(2))
    const piranesi = await addBook(alice, 'title: "Piranesi", status: READ')
    for (const id of [first, piranesi])
      await as(alice)(`mutation { setBookFavorite(id: "${id}", favorite: true) { id } }`)
    await as(alice)(
      'mutation { setSeriesFavorite(seriesId: "dune--frank-herbert", favorite: true) { favorite } }',
    )

    const result = await as(alice)(
      '{ myShelf { favorites { title } sagas { name favorite ownedCount genre volumes { title coverUrl } } } }',
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.myShelf).toEqual({
      favorites: [{ title: 'Piranesi' }],
      sagas: [
        {
          name: 'Dune',
          favorite: true,
          ownedCount: 2,
          genre: 'SCIENCE_FICTION',
          volumes: [
            { title: 'Dune 1', coverUrl: 'https://covers.example/dune-1.jpg' },
            { title: 'Dune 2', coverUrl: 'https://covers.example/dune-2.jpg' },
          ],
        },
      ],
    })
  })

  // What a friend coming back looks for is what is new: the last heart leads.
  test('lists the favourites most recently hearted first, with the date of the heart', async () => {
    const first = await addBook(alice, 'title: "Piranesi", status: READ')
    const second = await addBook(alice, 'title: "Hypérion", status: READ')
    await addBook(alice, dune(1))
    try {
      setSystemTime(new Date('2026-09-01T10:00:00Z'))
      await as(alice)(`mutation { setBookFavorite(id: "${first}", favorite: true) { id } }`)
      setSystemTime(new Date('2026-09-10T10:00:00Z'))
      await as(alice)(`mutation { setBookFavorite(id: "${second}", favorite: true) { id } }`)
      await as(alice)(
        'mutation { setSeriesFavorite(seriesId: "dune--frank-herbert", favorite: true) { favorite } }',
      )
    } finally {
      setSystemTime()
    }

    const result = await as(alice)(
      '{ myShelf { favorites { title favoritedAt } sagas { seriesId favoritedAt } } }',
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.myShelf).toEqual({
      favorites: [
        { title: 'Hypérion', favoritedAt: '2026-09-10T10:00:00.000Z' },
        { title: 'Piranesi', favoritedAt: '2026-09-01T10:00:00.000Z' },
      ],
      sagas: [{ seriesId: 'dune--frank-herbert', favoritedAt: '2026-09-10T10:00:00.000Z' }],
    })
  })

  test('is what a friend sees: hidden books left out, hearted sagas shown to them too', async () => {
    await addBook(alice, dune(1))
    const secret = await addBook(alice, 'title: "Un secret", status: READING')
    await as(alice)(`mutation { setBookHidden(id: "${secret}", hidden: true) { id } }`)
    await as(alice)(
      'mutation { setSeriesFavorite(seriesId: "dune--frank-herbert", favorite: true) { favorite } }',
    )
    await befriend()

    const own = await as(alice)('{ myShelf { reading { title } sagas { name favorite } } }')
    const seen = await as(bob)(
      '{ friendProfile(userId: "alice") { reading { title } sagas { name favorite } } }',
    )

    expect(own.data?.myShelf).toEqual({ reading: [], sagas: [{ name: 'Dune', favorite: true }] })
    expect(seen.data?.friendProfile).toEqual(own.data?.myShelf)
  })

  // "Récemment" on the profile: the last book finished, and when each book in
  // progress last moved.
  test('names the book finished last, and dates the activity on each book', async () => {
    const finish = async (id: string, finishedAt: string) => {
      const result = await as(alice)(
        `mutation { updateBook(id: "${id}", input: { finishedAt: "${finishedAt}" }) { id } }`,
      )
      expect(result.errors).toBeUndefined()
    }
    // Added before either finish, dated after both: a finish can neither
    // precede the start nor lie in the future.
    setSystemTime(new Date('2026-09-01T00:00:00Z'))
    const piranesi = await addBook(alice, 'title: "Piranesi", status: READ')
    const hyperion = await addBook(alice, 'title: "Hypérion", status: READ')
    setSystemTime(new Date('2026-09-15T00:00:00Z'))
    await finish(piranesi, '2026-09-05T00:00:00Z')
    await finish(hyperion, '2026-09-12T00:00:00Z')
    setSystemTime(new Date('2026-09-20T08:00:00Z'))
    await addBook(alice, 'title: "Les Furtifs", status: READING')
    setSystemTime()

    const result = await as(alice)(
      '{ myShelf { lastFinished { title finishedAt } reading { title lastActivityAt } } }',
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.myShelf).toEqual({
      lastFinished: { title: 'Hypérion', finishedAt: '2026-09-12T00:00:00.000Z' },
      reading: [{ title: 'Les Furtifs', lastActivityAt: '2026-09-20T08:00:00.000Z' }],
    })
  })

  // The recent activity draws the saga of the book in progress with its
  // covers, hearted or not; any other saga still carries none.
  test('carries the volumes of the saga being read, and of no other unhearted saga', async () => {
    await addBook(alice, dune(1).replace('status: READ', 'status: TO_READ'))
    await addBook(alice, dune(2).replace('status: READ', 'status: READING'))
    await addBook(
      alice,
      'title: "Hypérion", authors: ["Dan Simmons"], status: TO_READ, series: { id: "hyperion--dan-simmons", name: "Hypérion", volume: 1, kind: MAIN }',
    )

    const result = await as(alice)('{ myShelf { sagas { name favorite volumes { title } } } }')

    expect(result.errors).toBeUndefined()
    expect(result.data?.myShelf).toEqual({
      sagas: expect.arrayContaining([
        { name: 'Dune', favorite: false, volumes: [{ title: 'Dune 1' }, { title: 'Dune 2' }] },
        { name: 'Hypérion', favorite: false, volumes: [] },
      ]),
    })
  })

  // "Voir ses N livres": the friend's whole library, drawn as the reader's own.
  test('pages through a friend library newest first, dropped and hidden books aside', async () => {
    setSystemTime(new Date('2026-09-01T00:00:00Z'))
    await addBook(alice, 'title: "Ancien", status: TO_READ')
    setSystemTime(new Date('2026-09-02T00:00:00Z'))
    await addBook(alice, 'title: "Abandonné", status: DROPPED')
    setSystemTime(new Date('2026-09-03T00:00:00Z'))
    const secret = await addBook(alice, 'title: "Un secret", status: TO_READ')
    await as(alice)(`mutation { setBookHidden(id: "${secret}", hidden: true) { id } }`)
    setSystemTime(new Date('2026-09-04T00:00:00Z'))
    const recent = await addBook(alice, 'title: "Récent", status: READING')
    setSystemTime()
    await addBook(bob, 'title: "RÉCENT"')
    await befriend()

    const first = await as(bob)(
      '{ friendLibraryPage(userId: "alice", limit: 1) { books { id title inLibrary shelvedAt } hasMore } }',
    )
    const next = await as(bob)(
      `{ friendLibraryPage(userId: "alice", limit: 1, after: "${recent}") { books { title } hasMore } }`,
    )
    const dropped = await as(bob)(
      '{ friendLibraryPage(userId: "alice", status: DROPPED) { books { title } } }',
    )
    const counted = await as(bob)('{ friendProfile(userId: "alice") { bookCount } }')

    expect(first.errors).toBeUndefined()
    expect(first.data?.friendLibraryPage).toEqual({
      books: [
        { id: recent, title: 'Récent', inLibrary: true, shelvedAt: '2026-09-04T00:00:00.000Z' },
      ],
      hasMore: true,
    })
    expect(next.data?.friendLibraryPage).toEqual({ books: [{ title: 'Ancien' }], hasMore: false })
    expect(dropped.data?.friendLibraryPage).toEqual({ books: [{ title: 'Abandonné' }] })
    expect(counted.data?.friendProfile).toEqual({ bookCount: 2 })
  })

  // "Voir ses N séries": every saga with all its covers, the one shelved last first.
  test('pages through a friend sagas, each with every volume', async () => {
    setSystemTime(new Date('2026-09-01T00:00:00Z'))
    await addBook(
      alice,
      'title: "Hypérion", authors: ["Dan Simmons"], status: TO_READ, series: { id: "hyperion--dan-simmons", name: "Hypérion", volume: 1, kind: MAIN }',
    )
    setSystemTime(new Date('2026-09-05T00:00:00Z'))
    await addBook(alice, dune(1).replace('status: READ', 'status: TO_READ'))
    await addBook(alice, dune(2).replace('status: READ', 'status: TO_READ'))
    setSystemTime()
    await befriend()

    const first = await as(bob)(
      '{ friendSagaPage(userId: "alice", limit: 1) { sagas { id name shelvedAt volumes { title } } hasMore } }',
    )
    const page = first.data?.friendSagaPage as { sagas: { id: string }[] }
    const next = await as(bob)(
      `{ friendSagaPage(userId: "alice", limit: 1, after: ${JSON.stringify(page.sagas[0]?.id)}) { sagas { name volumes { title } } hasMore } }`,
    )
    const stranger = await as(carol)('{ friendSagaPage(userId: "alice") { hasMore } }')

    expect(first.errors).toBeUndefined()
    expect(first.data?.friendSagaPage).toEqual({
      sagas: [
        {
          id: expect.any(String),
          name: 'Dune',
          shelvedAt: '2026-09-05T00:00:00.000Z',
          volumes: [{ title: 'Dune 1' }, { title: 'Dune 2' }],
        },
      ],
      hasMore: true,
    })
    expect(next.data?.friendSagaPage).toEqual({
      sagas: [{ name: 'Hypérion', volumes: [{ title: 'Hypérion' }] }],
      hasMore: false,
    })
    expect(stranger.data?.friendSagaPage).toBeNull()
  })

  test('puts the book in progress touched most recently first', async () => {
    setSystemTime(new Date('2026-09-01T00:00:00Z'))
    await addBook(alice, 'title: "Ancien", status: READING')
    setSystemTime(new Date('2026-09-02T00:00:00Z'))
    const touched = await addBook(alice, 'title: "Repris", status: READING')
    setSystemTime(new Date('2026-09-03T00:00:00Z'))
    await addBook(alice, 'title: "Moyen", status: READING')
    // Any write counts as activity, the way a listening sync moving the
    // position does.
    setSystemTime(new Date('2026-09-04T00:00:00Z'))
    await as(alice)(`mutation { setBookNote(id: "${touched}", note: "Relu") { id } }`)

    const result = await as(alice)('{ myShelf { reading { title } } }')

    expect(result.data?.myShelf).toEqual({
      reading: [{ title: 'Repris' }, { title: 'Moyen' }, { title: 'Ancien' }],
    })
  })
})

describe('the friends list in figures', () => {
  const addBook = (owner: UserId, fields: string) =>
    as(owner)(`mutation { addBook(input: { ${fields} }) { id } }`)
  const idOf = (result: Awaited<ReturnType<typeof addBook>>) =>
    (result.data as { addBook: { id: string } }).addBook.id

  const stockAlice = async () => {
    await addBook(alice, 'title: "Dune", status: READING')
    await addBook(alice, 'title: "Hypérion"')
    await addBook(alice, 'title: "Fondation"')
    const loved = idOf(await addBook(alice, 'title: "Le Nom du vent", status: READ'))
    await as(alice)(`mutation { setBookFavorite(id: "${loved}", favorite: true) { id } }`)
    const secret = idOf(await addBook(alice, 'title: "Un secret", status: READING'))
    await as(alice)(`mutation { setBookHidden(id: "${secret}", hidden: true) { id } }`)
  }

  // The counts are what a friend may see: a hidden book in progress must not
  // show as a second book in progress, nor its title as the one being read.
  test('counts their favourites, books in progress and pile, hidden books left out', async () => {
    await stockAlice()
    await befriend()

    const result = await as(bob)(
      '{ friends { userId favoriteCount readingCount toReadCount readingTitle } }',
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.friends).toEqual([
      {
        userId: 'alice',
        favoriteCount: 1,
        readingCount: 1,
        toReadCount: 2,
        readingTitle: 'Dune',
      },
    ])
  })

  // One friendships query, then one document per friend for the names and one
  // for the figures — never their library.
  test('reads one view per friend, not their books', async () => {
    await stockAlice()
    await befriend()
    await as(bob)('{ friends { favoriteCount } }')

    startFakeRequest()
    const before = { docs: fake.docReads, queries: fake.queryReads }
    await as(bob)('{ friends { favoriteCount } }')

    expect(fake.queryReads - before.queries).toBe(1)
    expect(fake.docReads - before.docs).toBe(2)
  })

  test('follows a write made since the last count', async () => {
    await stockAlice()
    await befriend()
    await as(bob)('{ friends { toReadCount } }')

    await addBook(alice, 'title: "Piranesi"')
    const result = await as(bob)('{ friends { toReadCount } }')

    expect(result.data?.friends).toEqual([{ toReadCount: 3 }])
  })
})

describe("taking a book off a friend's shelf", () => {
  const addBook = (owner: UserId, fields: string) =>
    as(owner)(`mutation { addBook(input: { ${fields} }) { id } }`)
  const idOf = (result: Awaited<ReturnType<typeof addBook>>) =>
    (result.data as { addBook: { id: string } }).addBook.id
  const copy = (bookId: string, status = 'TO_READ') =>
    as(bob)(
      `mutation { addFriendBook(userId: "alice", bookId: "${bookId}", status: ${status}) { title authors status rating favorite recommendation { recommenderName } series { name volume } } }`,
    )

  const nameAlice = () =>
    as(alice)('mutation { completeOnboarding(input: { firstName: "Alice" }) { firstName } }')

  test('opens the book read-only, with whether the reader already owns it', async () => {
    const dune = idOf(
      await addBook(alice, 'title: "Dune", authors: ["Frank Herbert"], synopsis: "Arrakis."'),
    )
    await addBook(bob, 'title: "DUNE", authors: ["Frank Herbert"]')
    await befriend()

    const result = await as(bob)(
      `{ friendBook(userId: "alice", bookId: "${dune}") { title synopsis inLibrary } }`,
    )

    expect(result.errors).toBeUndefined()
    expect(result.data?.friendBook).toEqual({
      title: 'Dune',
      synopsis: 'Arrakis.',
      inLibrary: true,
    })
  })

  // The preview of the reader's own page opens their books on the same page.
  test("opens the reader's own shared book as a friend would, never a hidden one", async () => {
    const dune = idOf(await addBook(alice, 'title: "Dune", authors: ["Frank Herbert"]'))
    const secret = idOf(await addBook(alice, 'title: "Un secret"'))
    await as(alice)(`mutation { setBookHidden(id: "${secret}", hidden: true) { id } }`)

    const own = await as(alice)(
      `{ friendBook(userId: "alice", bookId: "${dune}") { title inLibrary } }`,
    )
    const hidden = await as(alice)(`{ friendBook(userId: "alice", bookId: "${secret}") { title } }`)

    expect(own.data?.friendBook).toEqual({ title: 'Dune', inLibrary: true })
    expect(hidden.data?.friendBook).toBeNull()
  })

  test('copies the catalogue facts, never what the friend made of the book', async () => {
    await nameAlice()
    const hyperion = idOf(
      await addBook(
        alice,
        'title: "Hypérion", authors: ["Dan Simmons"], status: READ, series: { id: "hyperion--dan-simmons", name: "Hypérion", volume: 1, kind: MAIN }',
      ),
    )
    await as(alice)(`mutation { setBookFavorite(id: "${hyperion}", favorite: true) { id } }`)
    await befriend()

    const result = await copy(hyperion)

    expect(result.errors).toBeUndefined()
    expect(result.data?.addFriendBook).toEqual({
      title: 'Hypérion',
      authors: ['Dan Simmons'],
      status: 'TO_READ',
      rating: null,
      favorite: false,
      recommendation: { recommenderName: 'Alice' },
      series: { name: 'Hypérion', volume: 1 },
    })
  })

  test('files it among the books read for a reader who had read it', async () => {
    const dune = idOf(await addBook(alice, 'title: "Dune"'))
    await befriend()

    const result = await copy(dune, 'READ')

    expect(result.data?.addFriendBook).toMatchObject({ status: 'READ' })
  })

  test('refuses a story the reader already owns', async () => {
    const dune = idOf(await addBook(alice, 'title: "Dune", authors: ["Frank Herbert"]'))
    await addBook(bob, 'title: "Dune", authors: ["Frank Herbert"]')
    await befriend()

    const result = await copy(dune)

    expect(result.errors?.[0]?.extensions?.code).toBe('ALREADY_IN_LIBRARY')
  })

  // A stranger, a hidden book and a missing one answer alike.
  test('refuses a hidden book and a stranger alike', async () => {
    const secret = idOf(await addBook(alice, 'title: "Un secret"'))
    await as(alice)(`mutation { setBookHidden(id: "${secret}", hidden: true) { id } }`)
    const dune = idOf(await addBook(alice, 'title: "Dune"'))

    const stranger = await copy(dune)
    await befriend()
    const hidden = await copy(secret)
    const page = await as(bob)(`{ friendBook(userId: "alice", bookId: "${secret}") { title } }`)

    expect(stranger.errors?.[0]?.extensions?.code).toBe('NOT_FOUND')
    expect(hidden.errors?.[0]?.extensions?.code).toBe('NOT_FOUND')
    expect(page.data?.friendBook).toBeNull()
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
