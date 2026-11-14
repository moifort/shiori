import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { idsTakeOneSeparator } = await import(
  '~/system/migration/migrations/037-ids-take-one-separator'
)

const quotas = await import('~/domain/quota/infrastructure/repository')
const scans = await import('~/domain/scan/infrastructure/repository')
const opinions = await import('~/domain/series-opinion/infrastructure/repository')

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

// The minutes between the deploy and the migration: the new code reads what
// is still stored under the legacy ids.
describe('before migration 037 has run', () => {
  const month = '2026-11' as never
  const reader = 'u1' as never

  test('a quota spent under its legacy id is not fresh, and the next scan counts on', async () => {
    fake.seed('ai-quotas', 'u1_2026-11', { userId: 'u1', month: '2026-11', scans: 4 })

    expect((await quotas.findBy(reader, month)).scans as number).toBe(4)
    await quotas.consume(reader, month, (quota) => ({
      ...quota,
      scans: (quota.scans + 1) as never,
    }))

    expect(fake.data('ai-quotas', 'u1~2026-11')?.scans).toBe(5)
    await migrate()
    expect(fake.data('ai-quotas', 'u1~2026-11')?.scans).toBe(5)
  })

  test('a cover cached under its legacy id is a hit, not a paid scan', async () => {
    fake.seed('scan-cache', `${hash}_fr`, {
      imageHash: hash,
      language: 'fr',
      cachedAt,
      result: { title: 'Dune', format: 'book' },
    })

    expect((await scans.findBy(hash as never, 'fr'))?.result.title as string).toBe('Dune')
  })

  test('an opinion stored under its legacy id is read, answered once, and removed whole', async () => {
    fake.seed('series-opinions', 'u1--dune', { userId: 'u1', seriesId: 'dune', rating: 2 })

    expect((await opinions.findBy(reader, 'dune'))?.rating as number).toBe(2)
    await opinions.save({ userId: reader, seriesId: 'dune' as never, rating: 5 as never })
    expect((await opinions.findAllByUser(reader)).map((opinion) => Number(opinion.rating))).toEqual(
      [5],
    )

    await opinions.remove(reader, 'dune')
    expect(await opinions.findAllByUser(reader)).toHaveLength(0)
    expect(fake.snapshot('series-opinions').size).toBe(0)
  })
})
