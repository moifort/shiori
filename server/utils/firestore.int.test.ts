import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { BeverageId } from '~/domain/beverage/types'
import type { UserId } from '~/domain/shared/types'
import { createFakeFirestore, fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { userBeverageRecordRepository } = await import('~/utils/firestore')

const userId = 'user-1' as UserId
type Record = { userId: UserId; beverageId: BeverageId; note: string }
const repo = userBeverageRecordRepository<Record>('records')

let fake = resetFakeFirestore()
beforeEach(() => {
  fake = resetFakeFirestore()
})

describe('userBeverageRecordRepository.findManyByBeverageIds', () => {
  const seed = () => {
    fake.seed('records', `${userId}_w1`, { userId, beverageId: 'w1', note: 'a' })
    fake.seed('records', `${userId}_w2`, { userId, beverageId: 'w2', note: 'b' })
    fake.seed('records', `${userId}_w3`, { userId, beverageId: 'w3', note: 'c' })
  }

  test('loads only the requested ids, one read each (no full scan)', async () => {
    seed()
    const before = fake.reads
    const result = await repo.findManyByBeverageIds(userId, ['w1', 'w3'] as BeverageId[])
    expect(result.map((r) => String(r.beverageId)).sort()).toEqual(['w1', 'w3'])
    expect(fake.reads - before).toBe(2)
  })

  test('returns [] with zero reads for an empty id list', async () => {
    seed()
    const before = fake.reads
    expect(await repo.findManyByBeverageIds(userId, [])).toEqual([])
    expect(fake.reads - before).toBe(0)
  })

  test('filters out ids that have no record', async () => {
    seed()
    const result = await repo.findManyByBeverageIds(userId, ['w1', 'missing'] as BeverageId[])
    expect(result.map((r) => String(r.beverageId))).toEqual(['w1'])
  })
})

describe('fake Firestore array operators', () => {
  test('array-contains matches a document holding the value', async () => {
    const local = createFakeFirestore()
    local.seed('beverages', 'w1', { userId: 'u1', searchIndex: ['margaux', 'chateau'] })
    local.seed('beverages', 'w2', { userId: 'u1', searchIndex: ['petrus'] })

    const snap = await local.db
      .collection('beverages')
      .where('searchIndex', 'array-contains', 'margaux')
      .get()

    expect(snap.docs.map((doc) => doc.ref.id)).toEqual(['w1'])
  })

  test('array-contains-any matches on any of the values', async () => {
    const local = createFakeFirestore()
    local.seed('beverages', 'w1', { userId: 'u1', searchIndex: ['margaux'] })
    local.seed('beverages', 'w2', { userId: 'u1', searchIndex: ['p:u1:alice'] })
    local.seed('beverages', 'w3', { userId: 'u1', searchIndex: ['petrus'] })

    const snap = await local.db
      .collection('beverages')
      .where('searchIndex', 'array-contains-any', ['margaux', 'p:u1:alice'])
      .get()

    expect(snap.docs.map((doc) => doc.ref.id)).toEqual(['w1', 'w2'])
  })

  test('a missing array never matches', async () => {
    const local = createFakeFirestore()
    local.seed('beverages', 'w1', { userId: 'u1' })

    const snap = await local.db
      .collection('beverages')
      .where('searchIndex', 'array-contains', 'margaux')
      .get()

    expect(snap.docs).toEqual([])
  })
})
