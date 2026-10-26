import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))
mock.module('~/domain/author/infrastructure/wikipedia', () => ({
  portraitOf: async () => undefined,
}))
mock.module('~/domain/author/infrastructure/open-library', () => ({
  openLibraryPortraitOf: async () => undefined,
}))
mock.module('~/domain/author/infrastructure/wikidata', () => ({
  wikidataPortraitOf: async (name: string) =>
    name === 'Morgan Audic' ? 'https://upload.wikimedia.org/audic.jpg' : undefined,
}))

const { facelessAuthorsSoughtAgain } = await import(
  '~/system/migration/migrations/031-faceless-authors-sought-again'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const author = (name: string, extra: object = {}) => ({
  key: name.toLowerCase().replace(' ', '-'),
  name,
  series: [],
  books: [],
  cataloguedAt: new Date('2026-09-30'),
  ...extra,
})

const run = () => facelessAuthorsSoughtAgain.migrate({ db: fakeDb() })

describe('faceless authors sought again', () => {
  test('gives a face to an author the lookup now finds', async () => {
    fake.seed('authors', 'morgan-audic', author('Morgan Audic'))

    expect(await run()).toEqual({ ok: true, transformed: 1 })
    expect(fake.data('authors', 'morgan-audic')?.portraitUrl).toBe(
      'https://upload.wikimedia.org/audic.jpg',
    )
  })

  test('records when an author still without a face was sought', async () => {
    fake.seed('authors', 'eiichiro-oda', author('Eiichiro Oda'))

    expect(await run()).toEqual({ ok: true, transformed: 0 })
    expect(fake.data('authors', 'eiichiro-oda')?.portraitSoughtAt).toBeInstanceOf(Date)
  })

  test('leaves an author who has a face alone', async () => {
    fake.seed(
      'authors',
      'morgan-audic',
      author('Morgan Audic', { portraitUrl: 'https://upload.wikimedia.org/kept.jpg' }),
    )

    expect(await run()).toEqual({ ok: true, transformed: 0 })
    expect(fake.data('authors', 'morgan-audic')?.portraitUrl).toBe(
      'https://upload.wikimedia.org/kept.jpg',
    )
  })
})
