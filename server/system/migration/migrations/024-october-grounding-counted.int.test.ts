import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { octoberGroundingCounted } = await import(
  '~/system/migration/migrations/024-october-grounding-counted'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

describe("October's grounded calls", () => {
  test('are counted from the bill, on top of the calls counted since', async () => {
    fake.seed('grounding-months', '2026-10', { month: '2026-10', calls: 6 })

    expect(await octoberGroundingCounted.migrate({ db: fakeDb() })).toEqual({
      ok: true,
      transformed: 1,
    })
    expect(fake.data('grounding-months', '2026-10')).toEqual({ month: '2026-10', calls: 1454 })
  })

  test('are counted from the bill when nothing was counted yet', async () => {
    await octoberGroundingCounted.migrate({ db: fakeDb() })

    expect(fake.data('grounding-months', '2026-10')).toEqual({ month: '2026-10', calls: 1448 })
  })

  test('are left as they are once the count is already past the bill', async () => {
    fake.seed('grounding-months', '2026-10', { month: '2026-10', calls: 2000 })

    expect(await octoberGroundingCounted.migrate({ db: fakeDb() })).toEqual({
      ok: true,
      transformed: 0,
    })
    expect(fake.data('grounding-months', '2026-10')?.calls).toBe(2000)
  })
})
