import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { unnumberedVolumesFiled } = await import(
  '~/system/migration/migrations/039-unnumbered-volumes-filed'
)

let fake = resetFakeFirestore()

const crescentCity = 'crescent-city--sarah-j-maas~en'

const seedBook = (id: string, title: string, volume?: number, userId = 'bob') =>
  fake.seed('books', id, {
    userId,
    title,
    language: 'en',
    series: {
      id: crescentCity,
      saga: 'crescent-city--sarah-j-maas',
      name: 'Crescent City',
      kind: 'main',
      ...(volume !== undefined ? { volume } : {}),
    },
  })

beforeEach(() => {
  fake = resetFakeFirestore()
  fake.seed('series', crescentCity, {
    id: crescentCity,
    name: 'Crescent City',
    language: 'en',
    volumes: [
      { number: 1, title: 'House of Earth and Blood', kind: 'main' },
      { number: 2, title: 'House of Sky and Breath', kind: 'main' },
      { number: 3, title: 'House of Flame and Shadow', kind: 'main' },
    ],
  })
})

describe('unnumbered volumes filed', () => {
  test('numbers a volume held unnumbered from its catalogue, and flags its reader', async () => {
    seedBook('b1', 'House of Earth and Blood')
    seedBook('b2', 'House of Sky and Breath', 2)
    seedBook('b3', 'Crescent City', undefined, 'ann')

    const result = await unnumberedVolumesFiled.migrate({ db: fakeDb() })

    expect(result).toEqual({ ok: true, transformed: 1 })
    expect(fake.data('books', 'b1')?.series).toMatchObject({ id: crescentCity, volume: 1 })
    expect((fake.data('books', 'b2')?.series as { volume?: number } | undefined)?.volume).toBe(2)
    // The saga's own name tells no volume apart.
    expect(
      (fake.data('books', 'b3')?.series as { volume?: number } | undefined)?.volume,
    ).toBeUndefined()
    expect(fake.data('analytics', 'bob')?.stale).toBe(true)
    expect(fake.data('analytics', 'ann')).toBeNull()
  })

  test('leaves a numbered volume alone, even numbered otherwise', async () => {
    seedBook('b1', 'House of Earth and Blood', 4)

    expect(await unnumberedVolumesFiled.migrate({ db: fakeDb() })).toEqual({
      ok: true,
      transformed: 0,
    })
    expect((fake.data('books', 'b1')?.series as { volume?: number } | undefined)?.volume).toBe(4)
  })

  test('changes nothing when run again', async () => {
    seedBook('b1', 'House of Earth and Blood')
    await unnumberedVolumesFiled.migrate({ db: fakeDb() })

    expect(await unnumberedVolumesFiled.migrate({ db: fakeDb() })).toEqual({
      ok: true,
      transformed: 0,
    })
  })
})
