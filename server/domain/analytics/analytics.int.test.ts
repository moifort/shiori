import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { SeriesId } from '~/domain/series/types'
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

const { BookUseCase } = await import('~/domain/book/use-case')
const { AnalyticsUseCase } = await import('~/domain/analytics/use-case')
const { TimeZone } = await import('~/domain/analytics/primitives')
const { BookTitle } = await import('~/domain/shared/primitives')
const { PageCount, StarRating } = await import('~/domain/book/primitives')
const { UserUseCase } = await import('~/domain/user/use-case')
const { SeriesOpinionUseCase } = await import('~/domain/series-opinion/use-case')
const { VIEW_VERSION } = await import('~/domain/analytics/business-rules')

const reader = 'reader-1' as UserId
const paris = TimeZone('Europe/Paris')

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const addBook = async (title: string, status: 'to-read' | 'reading' | 'read' = 'to-read') =>
  BookUseCase.add(reader, { title: BookTitle(title), status, pageCount: PageCount(300) })

describe('keeping the view in step with the library', () => {
  test('rebuilds the view after a book is added', async () => {
    await addBook('Le Nom du vent', 'reading')

    const view = fake.data('analytics', reader)
    expect(view?.stale).toBe(false)
    expect(view?.reading).toHaveLength(1)
  })

  test('marks the view stale in the very batch that writes the book', async () => {
    await addBook('Le Nom du vent')

    const [batch] = fake.batches
    expect(batch.ops.map((op) => [op.type, op.ref.collectionPath])).toEqual([
      ['set', 'books'],
      ['merge', 'analytics'],
    ])
  })

  test('follows a rating, which finishes the book', async () => {
    const book = await addBook('Le Nom du vent', 'reading')

    await BookUseCase.rate(reader, book.id, StarRating(5))

    const view = fake.data('analytics', reader)
    expect(view?.reading).toHaveLength(0)
    expect(view?.finishes).toHaveLength(1)
  })

  test('follows a deletion', async () => {
    const book = await addBook('Le Nom du vent')

    await BookUseCase.remove(reader, book.id)

    expect(fake.data('analytics', reader)?.toRead).toHaveLength(0)
  })

  test('leaves the view alone when the book does not exist', async () => {
    await addBook('Le Nom du vent')
    const before = fake.data('analytics', reader)

    const outcome = await BookUseCase.setHidden(reader, 'missing' as never, true)

    expect(outcome).toBe('not-found')
    expect(fake.data('analytics', reader)).toEqual(before)
  })

  // A heart on a saga is a figure of the dashboard, so it goes through the same
  // door as a book: flagged in the batch, rebuilt after it.
  test('follows a saga hearted, in the very batch that writes the opinion', async () => {
    await addBook('Dune')

    await SeriesOpinionUseCase.setFavorite(reader, 'dune--frank-herbert' as SeriesId, true)

    const batch = fake.batches.at(-1)
    expect(batch?.ops.map((op) => [op.type, op.ref.collectionPath])).toEqual([
      ['set', 'series-opinions'],
      ['merge', 'analytics'],
    ])
    expect(fake.data('analytics', reader)?.favoriteSeriesCount).toBe(1)
  })

  test('rebuilds a view stored by an older rule set on its next read', async () => {
    await addBook('Le Nom du vent')
    fake.seed('analytics', reader, { ...fake.data('analytics', reader), version: 1 })

    await AnalyticsUseCase.dashboard(reader, paris)

    expect(fake.data('analytics', reader)?.version).toBe(VIEW_VERSION)
  })

  test('keeps the time zone of the last dashboard read across a rebuild', async () => {
    await addBook('Le Nom du vent')
    await AnalyticsUseCase.dashboard(reader, paris)

    await addBook('La Peur du sage')

    expect(fake.data('analytics', reader)?.timeZone).toBe('Europe/Paris')
  })
})

describe('reading the dashboard', () => {
  test('costs one document read and no query when the view is fresh', async () => {
    await addBook('Le Nom du vent', 'reading')
    await AnalyticsUseCase.dashboard(reader, paris)
    const before = { docs: fake.docReads, queries: fake.queryReads }

    const dashboard = await AnalyticsUseCase.dashboard(reader, paris)

    expect(dashboard.reading).toHaveLength(1)
    expect(fake.docReads - before.docs).toBe(1)
    expect(fake.queryReads - before.queries).toBe(0)
  })

  test('rebuilds a view a failed refresh left stale', async () => {
    await addBook('Le Nom du vent', 'reading')
    await AnalyticsUseCase.dashboard(reader, paris)
    fake.seed('analytics', reader, { ...fake.data('analytics', reader), stale: true, reading: [] })

    const dashboard = await AnalyticsUseCase.dashboard(reader, paris)

    expect(dashboard.reading).toHaveLength(1)
    expect(fake.data('analytics', reader)?.stale).toBe(false)
  })

  test('builds the view on first read', async () => {
    const dashboard = await AnalyticsUseCase.dashboard(reader, paris)

    expect(dashboard.libraryIsEmpty).toBe(true)
    expect(fake.data('analytics', reader)?.timeZone).toBe('Europe/Paris')
  })

  test('draws the covers it serves from their source', async () => {
    await BookUseCase.add(reader, {
      title: BookTitle('Le Nom du vent'),
      status: 'reading',
      publishedCoverUrl: 'https://covers.openlibrary.org/b/isbn/9782352943556-M.jpg' as never,
    })

    const dashboard = await AnalyticsUseCase.dashboard(reader, paris)

    expect(String(dashboard.reading[0].coverUrl)).toContain('openlibrary')
  })
})

describe('deleting the account', () => {
  test('removes the view with the books', async () => {
    await addBook('Le Nom du vent')

    await UserUseCase.deleteAccount(reader)

    expect(fake.data('analytics', reader)).toBeNull()
  })
})
