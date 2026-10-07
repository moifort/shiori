import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { graphql } from 'graphql'
import type { UserId } from '~/domain/shared/types'
import { type FakeFirestore, fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/object-store', () => ({
  objectStore: () => ({ downloadUrl: async () => 'https://fake.store/cover' }),
}))
mock.module('~/system/identity', () => ({ deleteAuthUser: async () => undefined }))
const { schema } = await import('~/domain/shared/graphql/schema')
const { BookUseCase } = await import('~/domain/book/use-case')
const { AuthorName, BookTitle } = await import('~/domain/shared/primitives')

const alice = 'alice' as UserId
const bob = 'bob' as UserId
const french = { node: { req: { headers: { 'accept-language': 'fr-FR' } } } }
const as = (userId: UserId) => (source: string, variableValues?: Record<string, unknown>) =>
  graphql({ schema, source, contextValue: { event: french, userId }, variableValues })

let fake: FakeFirestore

const shelve = async (
  userId: UserId,
  title: string,
  language: 'en' | 'fr',
  format: 'book' | 'audiobook' = 'book',
) =>
  (
    await BookUseCase.add(userId, {
      title: BookTitle(title),
      authors: [AuthorName('Brandon Sanderson')],
      status: 'to-read',
      language,
      format,
    })
  ).id

/** What the web found of Wind and Truth, as the hourly pass would have kept
 *  it: every edition awaited below is watched already, so no model is asked. */
const watched = (format: 'book' | 'audiobook') => {
  const key = `wind-and-truth--brandon-sanderson--${format}--fr`
  fake.seed('edition-watches', key, {
    key,
    title: 'Wind and Truth',
    author: 'Brandon Sanderson',
    originalLanguage: 'en',
    format,
    language: 'fr',
    checkedAt: new Date(),
    found: {
      title: 'Vent et vérité',
      date: '2026-09-20',
      ...(format === 'audiobook' ? { asin: 'B0DM67WR2V' } : {}),
    },
  })
}

beforeEach(() => {
  fake = resetFakeFirestore()
  fake.seed('analytics', bob, { userId: bob, audiobookCount: 2 })
  watched('book')
  watched('audiobook')
})

const AWAITED = `id format state title originalTitle authors date storeUrl coverUrl`

describe('awaiting a book of one’s own', () => {
  test('offers its edition in the app’s language, and awaits it', async () => {
    const bookId = await shelve(bob, 'Wind and Truth', 'en')

    const offer = await as(bob)(
      'query ($bookId: BookId!) { bookEditionOffer(bookId: $bookId) { formats awaited { id } } }',
      { bookId },
    )
    expect(offer.data?.bookEditionOffer).toEqual({ formats: ['BOOK', 'AUDIOBOOK'], awaited: [] })

    const awaited = await as(bob)(
      `mutation ($bookId: BookId!) { awaitBookEdition(bookId: $bookId, format: AUDIOBOOK) { ${AWAITED} } }`,
      { bookId },
    )
    expect(awaited.errors).toBeUndefined()
    expect(awaited.data?.awaitBookEdition).toMatchObject({
      format: 'AUDIOBOOK',
      state: 'AVAILABLE',
      title: 'Vent et vérité',
      originalTitle: 'Wind and Truth',
      authors: ['Brandon Sanderson'],
      date: '2026-09-20',
      storeUrl: 'https://www.audible.fr/pd/B0DM67WR2V',
    })

    const listed = await as(bob)('{ awaitedEditions(format: AUDIOBOOK) { title state } }')
    expect(listed.data?.awaitedEditions).toEqual([{ title: 'Vent et vérité', state: 'AVAILABLE' }])
  })

  test('refuses a format the page does not offer', async () => {
    const bookId = await shelve(bob, 'Oathbringer', 'fr')

    const result = await as(bob)(
      'mutation ($bookId: BookId!) { awaitBookEdition(bookId: $bookId, format: BOOK) { id } }',
      { bookId },
    )

    expect(result.errors?.[0]?.extensions?.code).toBe('BAD_USER_INPUT')
  })

  test('stops awaiting an edition', async () => {
    const bookId = await shelve(bob, 'Wind and Truth', 'en')
    const awaited = await as(bob)(
      'mutation ($bookId: BookId!) { awaitBookEdition(bookId: $bookId, format: BOOK) { id } }',
      { bookId },
    )
    const { id } = (awaited.data as { awaitBookEdition: { id: string } }).awaitBookEdition

    const stopped = await as(bob)(
      'mutation ($id: AwaitedEditionId!) { stopAwaitingEdition(id: $id) }',
      { id },
    )

    expect(stopped.data?.stopAwaitingEdition).toBe(true)
    const listed = await as(bob)('{ awaitedEditions(format: BOOK) { id } }')
    expect(listed.data?.awaitedEditions).toEqual([])
  })
})

describe('awaiting a book from a scan, without adding it', () => {
  const AWAIT_SCANNED = `mutation ($book: ScannedBookInput!) {
    awaitScannedEdition(book: $book, format: AUDIOBOOK) { id state title bookId sourceBookId }
  }`
  const scanned = {
    title: 'Wind and Truth',
    authors: ['Brandon Sanderson'],
    format: 'BOOK',
    language: 'EN',
  }

  test('awaits it with no book on the shelf, and lists it', async () => {
    const result = await as(bob)(AWAIT_SCANNED, { book: scanned })

    expect(result.errors).toBeUndefined()
    const awaited = (result.data as { awaitScannedEdition: Record<string, unknown> })
      .awaitScannedEdition
    expect(awaited).toMatchObject({
      state: 'AVAILABLE',
      title: 'Vent et vérité',
      sourceBookId: null,
    })
    expect(awaited.bookId).toBe(awaited.id)
    expect(fake.snapshot('books').size).toBe(0)
    const listed = await as(bob)('{ awaitedEditions(format: AUDIOBOOK) { title sourceBookId } }')
    expect(listed.data?.awaitedEditions).toEqual([{ title: 'Vent et vérité', sourceBookId: null }])
  })

  test('shows it awaited on the book’s page once the book is added after all', async () => {
    await as(bob)(AWAIT_SCANNED, { book: scanned })
    const bookId = await shelve(bob, 'Wind and Truth', 'en')

    const offer = await as(bob)(
      'query ($bookId: BookId!) { bookEditionOffer(bookId: $bookId) { awaited { format } } }',
      { bookId },
    )

    expect(offer.data?.bookEditionOffer).toEqual({ awaited: [{ format: 'AUDIOBOOK' }] })
  })

  test('refuses a format the review does not offer', async () => {
    const result = await as(bob)(
      `mutation ($book: ScannedBookInput!) { awaitScannedEdition(book: $book, format: BOOK) { id } }`,
      { book: { ...scanned, language: 'FR' } },
    )

    expect(result.errors?.[0]?.extensions?.code).toBe('BAD_USER_INPUT')
  })
})

describe('a book a scan proposes, not added yet', () => {
  const FORMATS =
    'query ($language: BookLanguage!, $format: BookFormat!) { draftEditionFormats(language: $language, format: $format) }'

  test('is offered translated and recorded, to a reader who never listened too', async () => {
    const result = await as(alice)(FORMATS, { language: 'EN', format: 'BOOK' })
    expect(result.data?.draftEditionFormats).toEqual(['BOOK', 'AUDIOBOOK'])
  })

  test('is offered only recorded in the app’s language', async () => {
    const result = await as(bob)(FORMATS, { language: 'FR', format: 'BOOK' })
    expect(result.data?.draftEditionFormats).toEqual(['AUDIOBOOK'])
  })

  test('is offered nothing as a recording in the app’s language', async () => {
    const result = await as(bob)(FORMATS, { language: 'FR', format: 'AUDIOBOOK' })
    expect(result.data?.draftEditionFormats).toEqual([])
  })
})

describe('awaiting a friend’s book', () => {
  const befriend = async () => {
    const invitation = await as(alice)('mutation { inviteFriend { code } }')
    const { code } = (invitation.data as { inviteFriend: { code: string } }).inviteFriend
    await as(bob)('mutation ($code: String!) { acceptFriendInvitation(code: $code) { userId } }', {
      code,
    })
  }

  test('offers a printed book in the app’s language recorded', async () => {
    await befriend()
    const bookId = await shelve(alice, 'La Voie des rois', 'fr')

    const offer = await as(bob)(
      `query ($userId: UserId!, $bookId: BookId!) {
        friendBookEditionOffer(userId: $userId, bookId: $bookId) { formats }
      }`,
      { userId: alice, bookId },
    )

    expect(offer.errors).toBeUndefined()
    expect(offer.data?.friendBookEditionOffer).toEqual({ formats: ['AUDIOBOOK'] })
  })

  test('awaits it, remembering whose shelf it was seen on', async () => {
    await befriend()
    const bookId = await shelve(alice, 'Wind and Truth', 'en')

    const awaited = await as(bob)(
      `mutation ($userId: UserId!, $bookId: BookId!) {
        awaitFriendBookEdition(userId: $userId, bookId: $bookId, format: BOOK) { ownerId bookId }
      }`,
      { userId: alice, bookId },
    )

    expect(awaited.errors).toBeUndefined()
    expect(awaited.data?.awaitFriendBookEdition).toEqual({ ownerId: alice, bookId })
  })

  test('is refused for a stranger’s book', async () => {
    const bookId = await shelve(alice, 'Wind and Truth', 'en')

    const awaited = await as(bob)(
      `mutation ($userId: UserId!, $bookId: BookId!) {
        awaitFriendBookEdition(userId: $userId, bookId: $bookId, format: BOOK) { id }
      }`,
      { userId: alice, bookId },
    )

    expect(awaited.errors?.[0]?.extensions?.code).toBe('NOT_FOUND')
  })
})
