import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { formatsNamedBySubgenres } = await import(
  '~/system/migration/migrations/028-formats-named-by-subgenres'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const run = () => formatsNamedBySubgenres.migrate({ db: fakeDb() })

describe('formats named by subgenres', () => {
  test('moves a format from the subgenres of a printed book to its format', async () => {
    fake.seed('books', 'uw1', {
      userId: 'r',
      title: 'La Désobéissance',
      format: 'book',
      subgenres: ['Space Opera', 'Bande Dessinée'],
    })

    expect(await run()).toEqual({ ok: true, transformed: 1 })
    expect(fake.data('books', 'uw1')).toMatchObject({
      format: 'bande-dessinee',
      subgenres: ['Space Opera'],
    })
  })

  test('leaves a manga, a recording and a plain book untouched', async () => {
    fake.seed('books', 'manga', { userId: 'r', format: 'manga', subgenres: ['Bande Dessinée'] })
    fake.seed('books', 'audio', { userId: 'r', format: 'audiobook', subgenres: ['Manga'] })
    fake.seed('books', 'novel', { userId: 'r', format: 'book', subgenres: ['Dark Fantasy'] })
    fake.seed('books', 'bare', { userId: 'r', format: 'book' })

    expect(await run()).toEqual({ ok: true, transformed: 0 })
  })
})
