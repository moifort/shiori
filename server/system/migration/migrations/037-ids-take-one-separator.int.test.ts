import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { idsTakeOneSeparator } = await import(
  '~/system/migration/migrations/037-ids-take-one-separator'
)

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const hash = 'a'.repeat(64)
const cachedAt = new Date('2026-11-01T08:00:00Z')

const migrate = () => idsTakeOneSeparator.migrate({ db: fakeDb() })

describe('ids take one separator', () => {
  test('moves every legacy id to its tilde id, the document unchanged', async () => {
    fake.seed('ai-quotas', 'u1_2026-11', { userId: 'u1', month: '2026-11', scans: 3 })
    fake.seed('scan-cache', `${hash}_fr`, { imageHash: hash, language: 'fr', cachedAt })
    fake.seed('series-opinions', 'u1--dune--frank-herbert', {
      userId: 'u1',
      seriesId: 'dune--frank-herbert',
      rating: 4,
    })
    fake.seed('author-favorites', 'u1--frank-herbert', { userId: 'u1', authorKey: 'frank-herbert' })
    fake.seed('narrator-favorites', 'u1--bernard-gabay', {
      userId: 'u1',
      narratorKey: 'bernard-gabay',
    })

    expect(await migrate()).toEqual({ ok: true, transformed: 5 })

    expect([...fake.snapshot('ai-quotas').keys()]).toEqual(['u1~2026-11'])
    expect(fake.data('ai-quotas', 'u1~2026-11')).toEqual({
      userId: 'u1',
      month: '2026-11',
      scans: 3,
    })
    expect([...fake.snapshot('scan-cache').keys()]).toEqual([`${hash}~fr`])
    expect(fake.data('scan-cache', `${hash}~fr`)?.cachedAt).toEqual(cachedAt)
    expect([...fake.snapshot('series-opinions').keys()]).toEqual(['u1~dune--frank-herbert'])
    expect(fake.data('series-opinions', 'u1~dune--frank-herbert')?.rating).toBe(4)
    expect([...fake.snapshot('author-favorites').keys()]).toEqual(['u1~frank-herbert'])
    expect([...fake.snapshot('narrator-favorites').keys()]).toEqual(['u1~bernard-gabay'])
  })

  test('never clobbers what was written under the new id since the deploy', async () => {
    fake.seed('ai-quotas', 'u1_2026-11', { userId: 'u1', month: '2026-11', scans: 5 })
    fake.seed('ai-quotas', 'u1~2026-11', { userId: 'u1', month: '2026-11', scans: 4 })
    fake.seed('ai-quotas', 'u2_2026-11', { userId: 'u2', month: '2026-11', scans: 1 })
    fake.seed('ai-quotas', 'u2~2026-11', { userId: 'u2', month: '2026-11', scans: 2 })
    fake.seed('series-opinions', 'u1--dune', { userId: 'u1', seriesId: 'dune', rating: 2 })
    fake.seed('series-opinions', 'u1~dune', { userId: 'u1', seriesId: 'dune', rating: 5 })

    await migrate()

    // The higher count stands: no scan spent under either id is handed back.
    expect(fake.data('ai-quotas', 'u1~2026-11')?.scans).toBe(5)
    expect(fake.data('ai-quotas', 'u2~2026-11')?.scans).toBe(2)
    expect(fake.data('ai-quotas', 'u1_2026-11')).toBeNull()
    expect(fake.data('series-opinions', 'u1~dune')?.rating).toBe(5)
    expect(fake.data('series-opinions', 'u1--dune')).toBeNull()
  })

  test('runs again without changing anything', async () => {
    fake.seed('ai-quotas', 'u1_2026-11', { userId: 'u1', month: '2026-11', scans: 3 })
    await migrate()
    const writes = fake.transactions.length

    expect(await migrate()).toEqual({ ok: true, transformed: 0 })
    expect(fake.transactions.length).toBe(writes)
    expect(fake.data('ai-quotas', 'u1~2026-11')?.scans).toBe(3)
  })

  test('leaves a document missing a part of its id where it is', async () => {
    fake.seed('series-opinions', 'u1--orphan', { userId: 'u1', rating: 3 })

    expect(await migrate()).toEqual({ ok: true, transformed: 0 })
    expect(fake.data('series-opinions', 'u1--orphan')?.rating).toBe(3)
  })
})
