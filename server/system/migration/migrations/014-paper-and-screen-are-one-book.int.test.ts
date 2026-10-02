import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { paperAndScreenAreOneBook } = await import(
  '~/system/migration/migrations/014-paper-and-screen-are-one-book'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const run = () => paperAndScreenAreOneBook.migrate({ db: fakeDb() })

const day = (date: string) => new Date(`${date}T10:00:00Z`)

const book = (id: string, fields: Record<string, unknown>) =>
  fake.seed('books', id, {
    userId: 'r',
    title: 'Dune',
    authors: ['Frank Herbert'],
    subgenres: [],
    narrators: [],
    status: 'to-read',
    hidden: false,
    addedAt: day('2026-01-01'),
    ...fields,
  })

describe('paper and screen are one book', () => {
  test('an ebook becomes a book on a screen, the rest are held on paper or heard', async () => {
    book('ebook', { title: 'Hyperion', format: 'ebook' })
    book('paper', { title: 'Fondation', format: 'manga' })
    book('heard', { title: 'Dune', format: 'audiobook' })

    expect(await run()).toEqual({ ok: true, transformed: 3 })
    expect(fake.data('books', 'ebook')).toMatchObject({ format: 'book', media: ['digital'] })
    expect(fake.data('books', 'paper')).toMatchObject({ format: 'manga', media: ['print'] })
    expect(fake.data('books', 'heard')).toMatchObject({ format: 'audiobook', media: [] })
  })

  test('a Kindle title keeps the cover it was imported with as its Kindle cover', async () => {
    book('kindle', {
      format: 'ebook',
      kindleAsin: 'B0G26NZ911',
      publishedCoverUrl: 'https://m.media-amazon.com/dune.jpg',
    })

    await run()
    expect(fake.data('books', 'kindle')?.kindleCoverUrl).toBe('https://m.media-amazon.com/dune.jpg')
  })

  test('a paperback and its Kindle copy become one record, the furthest reading kept', async () => {
    book('paper', {
      format: 'book',
      addedAt: day('2025-03-01'),
      isbn13: '9782266320481',
      pageCount: 900,
      status: 'to-read',
      rating: 3,
      note: 'Offert par Léa.',
    })
    book('kindle', {
      format: 'ebook',
      addedAt: day('2025-06-01'),
      kindleAsin: 'B0G26NZ911',
      publishedCoverUrl: 'https://m.media-amazon.com/dune.jpg',
      status: 'read',
      startedAt: day('2025-07-01'),
      finishedAt: day('2025-08-01'),
      rating: 5,
      favorite: true,
      favoritedAt: day('2025-08-01'),
      note: 'Relu sur la liseuse.',
    })
    fake.seed('awaited-editions', 'r--dune', {
      userId: 'r',
      source: { bookId: 'kindle', ownerId: 'r', title: 'Dune' },
    })
    fake.seed('awaited-editions', 'friend--dune', {
      userId: 'friend',
      source: { bookId: 'kindle', ownerId: 'someone-else', title: 'Dune' },
    })

    await run()
    expect(fake.data('books', 'kindle')).toBeNull()
    expect(fake.data('books', 'paper')).toMatchObject({
      format: 'book',
      media: ['print', 'digital'],
      isbn13: '9782266320481',
      pageCount: 900,
      kindleAsin: 'B0G26NZ911',
      kindleCoverUrl: 'https://m.media-amazon.com/dune.jpg',
      status: 'read',
      startedAt: day('2025-07-01'),
      finishedAt: day('2025-08-01'),
      shelvedAt: day('2025-08-01'),
      addedAt: day('2025-03-01'),
      rating: 5,
      favorite: true,
      note: 'Offert par Léa.\n\nRelu sur la liseuse.',
    })
    expect(fake.data('awaited-editions', 'r--dune')?.source).toMatchObject({ bookId: 'paper' })
    // Another reader's awaited edition names another owner's book.
    expect(fake.data('awaited-editions', 'friend--dune')?.source).toMatchObject({
      bookId: 'kindle',
    })
  })

  test('two editions in two languages, two volumes, or two paperbacks stay apart', async () => {
    book('fr', { format: 'book', language: 'fr' })
    book('en', { format: 'ebook', language: 'en' })
    book('t1', { title: 'Le Fléau', format: 'book', series: { id: 's', name: 'S', volume: 1 } })
    book('t2', { title: 'Le Fléau', format: 'ebook', series: { id: 's', name: 'S', volume: 2 } })
    book('poche', { title: 'Hypérion', format: 'book' })
    book('broché', { title: 'Hypérion', format: 'book' })
    book('heard', { title: 'Hypérion', format: 'audiobook' })

    await run()
    for (const id of ['fr', 'en', 't1', 't2', 'poche', 'broché', 'heard'])
      expect(fake.data('books', id)).not.toBeNull()
  })

  test('two readers never share a record', async () => {
    book('mine', { format: 'book' })
    book('theirs', { format: 'ebook', userId: 'other' })

    await run()
    expect(fake.data('books', 'mine')?.media).toEqual(['print'])
    expect(fake.data('books', 'theirs')?.media).toEqual(['digital'])
  })
})
