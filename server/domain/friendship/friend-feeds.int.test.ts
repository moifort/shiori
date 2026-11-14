import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import { type FakeFirestore, fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/system/object-store', () => ({
  objectStore: () => ({
    downloadUrl: async (path: string) => `https://fake.store/${path}`,
    removeByPrefix: async () => undefined,
  }),
}))

const { FriendshipUseCase } = await import('~/domain/friendship/use-case')

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
