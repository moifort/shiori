import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { volumesListedOnce } = await import('~/system/migration/migrations/034-volumes-listed-once')

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const run = () => volumesListedOnce.migrate({ db: fakeDb() })

const falck = 'erica-falck-et-patrik-hedstrom--camilla-lackberg'
const isbn13 = '9782330226251'
const found = (number: number, title: string, isbn?: string) => ({
  number,
  title,
  date: '2026-10-07',
  ...(isbn ? { isbn13: isbn } : {}),
})
const entry = (number: number, title: string) => ({ number, title, kind: 'main' })

describe('volumes listed once', () => {
  beforeEach(() => {
    fake.seed('saga-watches', `${falck}--fr`, {
      seriesId: falck,
      language: 'fr',
      volumes: [
        found(11, 'Le Nid du coucou', '9782330191122'),
        found(12, 'La Pleureuse', isbn13),
        found(13, 'La Pleureuse', isbn13),
      ],
    })
    fake.seed('series', `${falck}~fr`, {
      name: 'Erica Falck et Patrik Hedström',
      language: 'fr',
      volumes: [
        entry(11, 'Le Nid du coucou'),
        entry(12, 'La Pleureuse'),
        entry(13, 'La Pleureuse'),
      ],
    })
  })

  test('drops a volume repeating the title and ISBN of a lower one, from the watch and the catalogue', async () => {
    expect(await run()).toEqual({ ok: true, transformed: 2 })
    expect(fake.data('saga-watches', `${falck}--fr`)?.volumes).toEqual([
      found(11, 'Le Nid du coucou', '9782330191122'),
      found(12, 'La Pleureuse', isbn13),
    ])
    expect(fake.data('series', `${falck}~fr`)?.volumes).toEqual([
      entry(11, 'Le Nid du coucou'),
      entry(12, 'La Pleureuse'),
    ])
  })

  test('keeps a number a reader filed a book at', async () => {
    fake.seed('books', 'b', {
      userId: 'r',
      language: 'fr',
      title: 'La Pleureuse',
      series: { id: falck, name: 'Erica Falck et Patrik Hedström', volume: 13, kind: 'main' },
    })

    expect(await run()).toEqual({ ok: true, transformed: 0 })
    expect(fake.data('series', `${falck}~fr`)?.volumes).toHaveLength(3)
  })

  test('leaves alone volumes sharing only their ISBN or only their title, and runs twice harmlessly', async () => {
    fake.seed('saga-watches', 'other--fr', {
      seriesId: 'other',
      language: 'fr',
      volumes: [found(1, 'One', isbn13), found(2, 'Two', isbn13), found(3, 'One')],
    })

    expect(await run()).toEqual({ ok: true, transformed: 2 })
    expect(await run()).toEqual({ ok: true, transformed: 0 })
    expect(fake.data('saga-watches', 'other--fr')?.volumes).toHaveLength(3)
  })
})
