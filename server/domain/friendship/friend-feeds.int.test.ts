import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import {
  type FakeFirestore,
  fakeDb,
  inConcurrentFakeRequests,
  resetFakeFirestore,
} from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/identity', () => ({ deleteAuthUser: async () => undefined }))
mock.module('~/system/object-store', () => ({
  objectStore: () => ({
    downloadUrl: async (path: string) => `https://fake.store/${path}`,
    removeByPrefix: async () => undefined,
  }),
}))

const { FriendshipUseCase } = await import('~/domain/friendship/use-case')
const { AnalyticsUseCase } = await import('~/domain/analytics/use-case')
const { AnalyticsCommand } = await import('~/domain/analytics/command')
const { HEARTS_VERSION } = await import('~/domain/analytics/business-rules')
const { BookUseCase } = await import('~/domain/book/use-case')
const { BookCommand } = await import('~/domain/book/command')
const { BookQuery } = await import('~/domain/book/query')
const { SeriesOpinionUseCase } = await import('~/domain/series-opinion/use-case')
const { SeriesOpinionQuery } = await import('~/domain/series-opinion/query')
const { SeriesUseCase } = await import('~/domain/series/use-case')
const { UserUseCase } = await import('~/domain/user/use-case')
const { BookTitle } = await import('~/domain/shared/primitives')
const { CoverUrl } = await import('~/domain/book/primitives')
const { SeriesName } = await import('~/domain/series/primitives')

// The two feeds a reader's friends' hearts make: the dashboard's news and
// Découvrir's strip. What they answer for one library of friends is pinned
// here as it was answered when each feed read every friend's whole library,
// so serving them from a projection changes nothing a reader is shown.

const reader = 'reader' as UserId
const camille = 'camille' as UserId
const lou = 'lou' as UserId
const sacha = 'sacha' as UserId
const stranger = 'stranger' as UserId

const now = new Date('2026-10-15T16:00:00Z')
const daysAgo = (days: number) => new Date(now.getTime() - days * 24 * 60 * 60 * 1000)

let fake: FakeFirestore

const befriend = (left: UserId, right: UserId) => {
  const id = [left, right].sort().join('--')
  fake.seed('friendships', id, { id, userIds: [left, right].sort(), since: daysAgo(100) })
}

const shelve = (owner: UserId, id: string, fields: Record<string, unknown>) =>
  fake.seed('books', id, {
    id,
    userId: owner,
    authors: ['Dan Simmons'],
    format: 'book',
    media: ['print'],
    subgenres: [],
    narrators: [],
    language: 'fr',
    status: 'read',
    hidden: false,
    addedAt: daysAgo(300),
    ...fields,
  })

const inSaga = (saga: string, name: string, volume: number, language = 'fr', kind = 'main') => ({
  series: { id: `${saga}~${language}`, saga, name, volume, kind },
  language,
})

const opinion = (owner: UserId, saga: string, fields: Record<string, unknown>) =>
  fake.seed('series-opinions', `${owner}~${saga}`, { userId: owner, seriesId: saga, ...fields })

const compagnieNoire = 'la-compagnie-noire--glen-cook'
const assassinRoyal = 'l-assassin-royal--robin-hobb'
const aventuriers = 'les-aventuriers-de-la-mer--robin-hobb'
const dune = 'dune--frank-herbert'
const cachee = 'la-saga-cachee--anonyme'

const seedLibraries = () => {
  befriend(reader, camille)
  befriend(reader, lou)
  befriend(reader, sacha)
  fake.seed('users', camille, { userId: camille, firstName: 'Camille' })
  fake.seed('users', lou, { userId: lou, firstName: 'Lou' })
  fake.seed('users', stranger, { userId: stranger, firstName: 'Inconnu' })

  // The reader holds one story, one saga and one author the friends love.
  shelve(reader, 'r1', { title: 'Hypérion' })
  shelve(reader, 'r2', {
    title: 'Le Vaisseau magique',
    authors: ['Robin Hobb'],
    ...inSaga(aventuriers, 'Les Aventuriers de la mer', 1),
  })

  // Camille: two dated hearts, an undated one, a hidden one, a hearted saga in
  // two editions with a hidden volume and a hearted volume, a rated saga not
  // hearted, and a hearted saga of which nothing is shared.
  shelve(camille, 'c01', {
    title: 'Endymion',
    favorite: true,
    favoritedAt: daysAgo(3),
    rating: 5,
    genre: 'science-fiction',
    subgenres: [{ label: 'space opera', language: 'fr' }],
    synopsis: 'Deux siècles après la chute des portes distrans…',
    note: 'Encore mieux que le premier.',
    publisher: 'Robert Laffont',
    pageCount: 640,
    isbn13: '9782221068823',
    coverPath: 'covers/c01.jpg',
    startedAt: daysAgo(20),
    finishedAt: daysAgo(4),
    updatedAt: daysAgo(3),
  })
  shelve(camille, 'c02', { title: 'Hypérion', favorite: true, favoritedAt: daysAgo(5) })
  shelve(camille, 'c03', {
    title: 'Le Secret',
    authors: ['Personne'],
    favorite: true,
    favoritedAt: daysAgo(1),
    hidden: true,
  })
  shelve(camille, 'c04', {
    title: 'Ancien',
    authors: ['Ursula K. Le Guin'],
    favorite: true,
    addedAt: daysAgo(200),
    updatedAt: daysAgo(100),
  })
  shelve(camille, 'c05', {
    title: 'Le Château noir',
    authors: ['Glen Cook'],
    favorite: true,
    favoritedAt: daysAgo(10),
    genre: 'fantasy',
    subgenres: [{ label: 'dark fantasy', language: 'fr' }],
    ...inSaga(compagnieNoire, 'La Compagnie noire', 2),
  })
  shelve(camille, 'c06', {
    title: 'La Compagnie noire',
    authors: ['Glen Cook'],
    genre: 'fantasy',
    publishedCoverUrl: 'https://covers.example/c06.jpg',
    addedAt: daysAgo(60),
    ...inSaga(compagnieNoire, 'La Compagnie noire', 1),
  })
  shelve(camille, 'c07', {
    title: 'La Rose blanche',
    authors: ['Glen Cook'],
    hidden: true,
    ...inSaga(compagnieNoire, 'La Compagnie noire', 3),
  })
  shelve(camille, 'c08', {
    title: 'The Black Company',
    authors: ['Glen Cook'],
    format: 'book',
    media: ['digital'],
    kindleCoverUrl: 'https://m.media-amazon.com/images/c08.jpg',
    status: 'reading',
    ...inSaga(compagnieNoire, 'The Black Company', 1, 'en'),
  })
  shelve(camille, 'c09', {
    title: 'Les Annales, nouvelle',
    authors: ['Glen Cook'],
    status: 'to-read',
    ...inSaga(compagnieNoire, 'La Compagnie noire', 1, 'fr', 'novella'),
  })
  shelve(camille, 'c10', {
    title: 'Dune',
    authors: ['Frank Herbert'],
    status: 'reading',
    ...inSaga(dune, 'Dune', 1),
  })
  shelve(camille, 'c11', { title: 'Ilium' })
  shelve(camille, 'c12', {
    title: 'Caché',
    authors: ['Anonyme'],
    hidden: true,
    ...inSaga(cachee, 'La Saga cachée', 1),
  })
  opinion(camille, compagnieNoire, { favorite: true, favoritedAt: daysAgo(2), rating: 4 })
  opinion(camille, dune, { rating: 5 })
  opinion(camille, cachee, { favorite: true, favoritedAt: daysAgo(0.5) })

  // Lou: the same story as Camille hearted later, an old heart, a saga hearted
  // before the date was kept, and a hearted saga the reader holds.
  shelve(lou, 'l1', { title: 'Endymion', favorite: true, favoritedAt: daysAgo(1) })
  shelve(lou, 'l2', {
    title: 'Vieux coup de cœur',
    authors: ['Jean Giono'],
    favorite: true,
    favoritedAt: daysAgo(40),
  })
  shelve(lou, 'l3', {
    title: 'L’Apprenti assassin',
    authors: ['Robin Hobb'],
    updatedAt: daysAgo(30),
    ...inSaga(assassinRoyal, 'L’Assassin royal', 1),
  })
  shelve(lou, 'l4', {
    title: 'L’Assassin du roi',
    authors: ['Robin Hobb'],
    status: 'reading',
    startedAt: daysAgo(8),
    ...inSaga(assassinRoyal, 'L’Assassin royal', 2),
  })
  shelve(lou, 'l5', {
    title: 'Le Navire aux esclaves',
    authors: ['Robin Hobb'],
    ...inSaga(aventuriers, 'Les Aventuriers de la mer', 2),
  })
  opinion(lou, assassinRoyal, { favorite: true, rating: 5 })
  opinion(lou, aventuriers, { favorite: true, favoritedAt: daysAgo(4) })

  // Sacha hearts nothing; the stranger hearts what nobody may see.
  shelve(sacha, 's1', { title: 'Rien de spécial', authors: ['Quelqu’un'] })
  shelve(stranger, 'x1', {
    title: 'Hors du cercle',
    authors: ['Inconnu'],
    favorite: true,
    favoritedAt: daysAgo(1),
  })
}

beforeEach(() => {
  fake = resetFakeFirestore()
  seedLibraries()
})

describe('the friends’ last hearts, for the dashboard', () => {
  test('answer each friend’s newest heart of the month, as they always did', async () => {
    expect(await FriendshipUseCase.recentFavorites(reader, now)).toMatchSnapshot()
  })

  test('answer nothing to a reader without friends', async () => {
    expect(await FriendshipUseCase.recentFavorites(stranger, now)).toEqual([])
  })
})

describe('what the friends love, for Découvrir', () => {
  test('answer the books, sagas and authors the reader does not hold, as they always did', async () => {
    expect(await FriendshipUseCase.recommendations(reader)).toMatchSnapshot()
  })

  test('answer nothing to a reader without friends', async () => {
    expect(await FriendshipUseCase.recommendations(stranger)).toEqual({
      books: [],
      sagas: [],
      authors: [],
    })
  })
})

describe('the projections the feeds read', () => {
  const favorites = () => FriendshipUseCase.recentFavorites(reader, now)
  const recommendations = () => FriendshipUseCase.recommendations(reader, now)

  test('answer, once stored, what they answered when built', async () => {
    const [builtFavorites] = await inConcurrentFakeRequests([favorites])
    const [builtRecommendations] = await inConcurrentFakeRequests([recommendations])

    const [storedFavorites] = await inConcurrentFakeRequests([favorites])
    const [storedRecommendations] = await inConcurrentFakeRequests([recommendations])

    expect(storedFavorites).toEqual(builtFavorites)
    expect(storedRecommendations).toEqual(builtRecommendations)
    expect(storedFavorites[0]?.book?.favoritedAt).toEqual(daysAgo(1))
  })

  // Three friends, one of them with three hundred books more: once their
  // projections are built, an opening scans the friendships and the reader's
  // own library, and reads two documents per friend — their name and their
  // hearts — however large their libraries.
  test('read two documents per friend, never a friend’s library', async () => {
    for (let index = 0; index < 300; index += 1)
      shelve(camille, `noise-${index}`, { title: `Livre ${index}`, authors: ['Auteur'] })
    await inConcurrentFakeRequests([favorites])

    // Découvrir also reads, in one batch, the catalogue of the three authors
    // it shows, for their faces.
    for (const [feed, faces] of [
      [favorites, 0],
      [recommendations, 3],
    ] as const) {
      const before = { docs: fake.docReads, queries: fake.queryReads, queried: fake.queriedDocs }
      await inConcurrentFakeRequests<unknown>([feed])

      expect(fake.queryReads - before.queries).toBe(2)
      expect(fake.queriedDocs - before.queried).toBe(3 + 2)
      expect(fake.docReads - before.docs).toBe(3 + 3 + faces)
    }
  })

  // What a reader is entitled to see first after the deploy: no projection
  // exists, so each friend's is built once from their shelf — what every
  // opening used to cost — and stored for the next ones.
  test('are built on the first opening, from each friend’s shelf', async () => {
    const before = { queries: fake.queryReads, queried: fake.queriedDocs }

    await inConcurrentFakeRequests([favorites])

    // The friendships and the reader's library, then each friend's books and
    // saga opinions: 12 + 6 + 1 documents and 3 + 2 + 0.
    expect(fake.queryReads - before.queries).toBe(2 + 3 * 2)
    expect(fake.queriedDocs - before.queried).toBe(3 + 2 + (12 + 3) + (5 + 2) + 1)
    for (const friend of [camille, lou, sacha])
      expect(fake.data('shared-hearts', friend)).toMatchObject({
        version: HEARTS_VERSION,
        builtFrom: 0,
      })
    expect(fake.data('shared-hearts', stranger)).toBeNull()
  })

  test('are rebuilt once stored by an older rule set', async () => {
    await inConcurrentFakeRequests([favorites])
    fake.seed('shared-hearts', lou, { ...fake.data('shared-hearts', lou), version: 0 })
    const before = fake.queryReads

    await inConcurrentFakeRequests([favorites])

    expect(fake.queryReads - before).toBe(2 + 2)
    expect(fake.data('shared-hearts', lou)?.version).toBe(HEARTS_VERSION)
  })

  // The other way round, a projection would answer from before the write for
  // good: built from a library read before the write landed, then stored over
  // the write's flag.
  test('are rebuilt when a write lands while they are being built', async () => {
    await inConcurrentFakeRequests([favorites])
    const [state] = await (await import('~/domain/analytics/query')).AnalyticsQuery.hearts([lou])
    const [books, opinions] = await Promise.all([
      BookQuery.shared(lou),
      SeriesOpinionQuery.all(lou),
    ])

    await BookUseCase.setFavorite(lou, 'l1' as never, false)
    await AnalyticsCommand.rebuildHearts({
      userId: lou,
      books,
      opinions,
      builtFrom: state?.writes ?? 0,
      now,
    })
    const [hearts] = await inConcurrentFakeRequests([favorites])

    expect(hearts.find((heart) => heart.friendId === lou)?.saga?.name).toBe(
      SeriesName('Les Aventuriers de la mer'),
    )
  })

  test('go with the account', async () => {
    await inConcurrentFakeRequests([favorites])

    await UserUseCase.deleteAccount(lou)

    expect(fake.data('shared-hearts', lou)).toBeNull()
  })
})

// Every write that can change what a friend's feed draws — a heart, a
// rating, a "do not share", a book's saga, title, authors or cover — flags the
// projection with the view, so the next feed rebuilds it. Each is checked
// against what the feed answers afterwards, built before the write.
describe('a write to a friend’s shelf, on the next opening', () => {
  const favorites = async () =>
    (await inConcurrentFakeRequests([() => FriendshipUseCase.recentFavorites(reader, now)]))[0]
  const recommendations = async () =>
    (await inConcurrentFakeRequests([() => FriendshipUseCase.recommendations(reader, now)]))[0]
  const lastHeartOf = async (friend: UserId) =>
    (await favorites()).find((heart) => heart.friendId === friend)
  const pickedTitles = async () =>
    (await recommendations()).books.map((pick) => String(pick.item.title))
  const pickedSagas = async () =>
    (await recommendations()).sagas.map((pick) => String(pick.item.name))

  beforeEach(async () => {
    await favorites()
  })

  test('shows a book hearted', async () => {
    await BookUseCase.setFavorite(camille, 'c11' as never, true)

    expect(await pickedTitles()).toContain('Ilium')
  })

  test('forgets a heart taken back', async () => {
    await BookUseCase.setFavorite(lou, 'l1' as never, false)

    expect((await lastHeartOf(lou))?.book).toBeUndefined()
  })

  test('forgets a book marked "do not share"', async () => {
    await BookUseCase.setHidden(lou, 'l1' as never, true)

    expect((await lastHeartOf(lou))?.book).toBeUndefined()
  })

  test('forgets a book removed', async () => {
    await BookUseCase.remove(lou, 'l1' as never)

    expect((await lastHeartOf(lou))?.book).toBeUndefined()
  })

  test('shows a book retitled and its authors corrected', async () => {
    await BookUseCase.edit(lou, 'l1' as never, {
      title: BookTitle('Endymion, l’intégrale'),
      authors: ['Dan Simmons', 'Traducteur'] as never,
    })

    const book = (await lastHeartOf(lou))?.book
    expect(String(book?.title)).toBe('Endymion, l’intégrale')
    expect(book?.authors.map(String)).toEqual(['Dan Simmons', 'Traducteur'])
  })

  test('shows a cover changed', async () => {
    await BookUseCase.edit(camille, 'c06' as never, {
      publishedCoverUrl: CoverUrl('https://covers.example/new.jpg'),
    })

    expect(String((await lastHeartOf(camille))?.saga?.volumes[0]?.coverUrl)).toBe(
      'https://covers.example/new.jpg',
    )
  })

  test('shows a saga rated', async () => {
    await SeriesOpinionUseCase.rate(camille, compagnieNoire as never, 3 as never)

    expect((await lastHeartOf(camille))?.saga?.rating).toBe(3 as never)
  })

  test('forgets a saga’s heart taken back', async () => {
    await SeriesOpinionUseCase.setFavorite(lou, assassinRoyal as never, false)

    expect(await pickedSagas()).not.toContain('L’Assassin royal')
  })

  test('shows a saga hearted', async () => {
    await SeriesOpinionUseCase.setFavorite(camille, dune as never, true)

    expect(await pickedSagas()).toContain('Dune')
  })

  test('forgets a saga removed from the shelf', async () => {
    await SeriesUseCase.removeFromLibrary(camille, compagnieNoire as never)

    expect((await lastHeartOf(camille))?.saga).toBeUndefined()
  })

  test('shows a saga folded into another', async () => {
    await SeriesUseCase.mergeInto(lou, assassinRoyal as never, 'fr', aventuriers as never)

    expect(await pickedSagas()).not.toContain('L’Assassin royal')
  })

  test('shows a saga renamed by its catalogue', async () => {
    await BookUseCase.nameSeries(`${compagnieNoire}~fr` as never, SeriesName('Les Annales'))

    expect(String((await lastHeartOf(camille))?.saga?.name)).toBe('Les Annales')
  })

  // An import or a nightly sync writes past one batch: the projection is
  // flagged before the first book lands and again after the last, so one
  // built from part of them is not kept.
  test('shows what an import or a sync wrote, even read half-way', async () => {
    await AnalyticsUseCase.whileStale(camille, async () => {
      await BookCommand.setFavorite(camille, 'c11' as never, true)
      await favorites()
      await BookCommand.setFavorite(camille, 'c04' as never, false)
    })

    expect(await pickedTitles()).toContain('Ilium')
    expect(await pickedTitles()).not.toContain('Ancien')
  })
})

describe('a reader who hearts more than one document holds', () => {
  // Incompressible text, as a real synopsis is to gzip once there are
  // thousands of different ones.
  const noise = (seed: number) => {
    let state = seed
    return Array.from({ length: 1200 }, () => {
      state = (state * 1103515245 + 12345) % 2147483648
      return String.fromCharCode(33 + (state % 90))
    }).join('')
  }

  test('keeps the newest hearts that fit, and the feeds still draw the newest', async () => {
    for (let index = 0; index < 1500; index += 1)
      shelve(sacha, `heart-${index}`, {
        title: `Coup de cœur ${index}`,
        authors: [`Auteur ${index}`],
        synopsis: noise(index + 1),
        favorite: true,
        favoritedAt: daysAgo(60 + index),
      })
    shelve(sacha, 'newest', { title: 'Le plus récent', favorite: true, favoritedAt: daysAgo(0.1) })

    const [hearts] = await inConcurrentFakeRequests([
      () => FriendshipUseCase.recentFavorites(reader, now),
    ])

    const stored = fake.data('shared-hearts', sacha)
    expect(String(stored?.hearts).length).toBeLessThanOrEqual(900_000)
    const shared = (await AnalyticsUseCase.sharedHearts([sacha], now)).get(sacha)
    expect(shared?.truncated).toBe(true)
    expect(shared?.books.length).toBeGreaterThan(100)
    expect(shared?.books.length).toBeLessThan(1501)
    expect(shared?.books.some((book) => book.id === 'newest')).toBe(true)
    expect(shared?.books.some((book) => book.id === 'heart-1499')).toBe(false)
    expect(String(hearts.find((heart) => heart.friendId === sacha)?.book?.title)).toBe(
      'Le plus récent',
    )
  })
})
