import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { booksWithoutALanguageAreFrench } = await import(
  '~/system/migration/migrations/015-books-without-a-language-are-french'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const run = () => booksWithoutALanguageAreFrench.migrate({ db: fakeDb() })

const book = (id: string, fields: Record<string, unknown>) =>
  fake.seed('books', id, {
    userId: 'r',
    title: 'Blood of Hercules',
    authors: ['Jasmine Mas'],
    format: 'book',
    media: ['digital'],
    series: { id: 'trilogie-villains-of-lore--jasmine-mas', name: 'Trilogie Villains of Lore' },
    ...fields,
  })

describe('books without a language are French', () => {
  test('a book that records no language is French, one that records one keeps it', async () => {
    book('unnamed', {})
    book('french', { title: 'Bonds of Hercules', language: 'fr' })
    book('english', { title: 'Fourth Wing', language: 'en' })

    expect(await run()).toEqual({ ok: true, transformed: 1 })
    expect(fake.data('books', 'unnamed')?.language).toBe('fr')
    expect(fake.data('books', 'french')?.language).toBe('fr')
    expect(fake.data('books', 'english')?.language).toBe('en')
  })

  test('the reader whose shelf changed has their dashboard recomputed, no one else', async () => {
    fake.seed('analytics', 'r', { userId: 'r', stale: false, sagas: [] })
    book('unnamed', {})
    book('other', { userId: 'o', language: 'fr' })

    await run()
    expect(fake.data('analytics', 'r')).toMatchObject({ stale: true, sagas: [] })
    expect(fake.data('analytics', 'o')).toBeNull()
  })

  test('a second run finds nothing to do', async () => {
    book('unnamed', {})

    await run()
    expect(await run()).toEqual({ ok: true, transformed: 0 })
  })
})
