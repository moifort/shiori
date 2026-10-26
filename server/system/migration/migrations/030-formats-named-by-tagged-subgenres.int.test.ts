import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { formatsNamedByTaggedSubgenres } = await import(
  '~/system/migration/migrations/030-formats-named-by-tagged-subgenres'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const run = () => formatsNamedByTaggedSubgenres.migrate({ db: fakeDb() })

describe('formats named by tagged subgenres', () => {
  test('moves a format from the tagged subgenres of a printed book to its format', async () => {
    fake.seed('books', 'uw1', {
      userId: 'r',
      title: 'La Désobéissance',
      format: 'book',
      subgenres: [
        { label: 'Space Opera', language: 'fr' },
        { label: 'Bande Dessinée', language: 'fr' },
      ],
    })

    expect(await run()).toEqual({ ok: true, transformed: 1 })
    expect(fake.data('books', 'uw1')).toMatchObject({
      format: 'bande-dessinee',
      subgenres: [{ label: 'Space Opera', language: 'fr' }],
    })
  })

  test('still reads a subgenre stored as a bare string', async () => {
    fake.seed('books', 'old', { userId: 'r', format: 'book', subgenres: ['Manga'] })

    expect(await run()).toEqual({ ok: true, transformed: 1 })
    expect(fake.data('books', 'old')).toMatchObject({ format: 'manga', subgenres: [] })
  })

  test('leaves a manga, a recording and a plain book untouched', async () => {
    const bd = { label: 'Bande Dessinée', language: 'fr' }
    fake.seed('books', 'manga', { userId: 'r', format: 'manga', subgenres: [bd] })
    fake.seed('books', 'audio', { userId: 'r', format: 'audiobook', subgenres: [bd] })
    fake.seed('books', 'novel', {
      userId: 'r',
      format: 'book',
      subgenres: [{ label: 'Dark Fantasy', language: 'fr' }],
    })
    fake.seed('books', 'bare', { userId: 'r', format: 'book' })

    expect(await run()).toEqual({ ok: true, transformed: 0 })
  })
})
