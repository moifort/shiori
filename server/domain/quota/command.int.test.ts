import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore, startFakeRequest } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { PREMIUM_MONTHLY_SCANS } = await import('~/domain/quota/business-rules')
const { QuotaCommand } = await import('~/domain/quota/command')
const { QuotaQuery } = await import('~/domain/quota/query')

const user = (id: string) => id as UserId

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

// A balance already handed out: the welcome scans of the accounts onboarded before
// 2026-11-28 stay theirs to spend.
const HELD = 50
const holdCredit = (userId: UserId) => fake.seed('ai-credits', userId, { userId, scans: HELD })

const spend = (userId: UserId, times: number) =>
  Promise.all(Array.from({ length: times }, () => QuotaCommand.record(userId, 'premium')))

describe('recording a scan', () => {
  test('starts a never-touched month at zero and counts the first scan', async () => {
    expect((await QuotaQuery.ofCurrentMonth(user('u1'))).scans as number).toBe(0)

    await QuotaCommand.record(user('u1'), 'premium')

    expect((await QuotaQuery.ofCurrentMonth(user('u1'))).scans as number).toBe(1)
  })

  test('counts every scan that lands together, rather than losing one to a stale read', async () => {
    await spend(user('u1'), 3)

    expect((await QuotaQuery.ofCurrentMonth(user('u1'))).scans as number).toBe(3)
  })

  test('reads and writes the counter in one transaction, never as a bare set', async () => {
    await QuotaCommand.record(user('u1'), 'premium')

    expect(fake.transactions).toHaveLength(1)
    expect(fake.directWrites).toHaveLength(0)
  })

  test('keeps one account out of another account s counter', async () => {
    await QuotaCommand.record(user('u1'), 'premium')
    await QuotaCommand.record(user('u2'), 'premium')
    await QuotaCommand.record(user('u2'), 'premium')

    expect((await QuotaQuery.ofCurrentMonth(user('u1'))).scans as number).toBe(1)
    expect((await QuotaQuery.ofCurrentMonth(user('u2'))).scans as number).toBe(2)
  })
})

describe('which counter a scan is taken from', () => {
  test('spends the month first, leaving the granted scans untouched', async () => {
    holdCredit(user('u1'))

    expect(await QuotaCommand.record(user('u1'), 'premium')).toEqual({ on: 'monthly' })
    expect((await QuotaQuery.creditOf(user('u1'))).scans as number).toBe(HELD)
  })

  test('falls back to the granted scans once the month is spent', async () => {
    holdCredit(user('u1'))
    await spend(user('u1'), PREMIUM_MONTHLY_SCANS)

    expect(await QuotaCommand.record(user('u1'), 'premium')).toEqual({ on: 'credit' })
    expect((await QuotaQuery.creditOf(user('u1'))).scans as number).toBe(HELD - 1)
    // The month stops where its limit is: the grant absorbs the overflow.
    expect((await QuotaQuery.ofCurrentMonth(user('u1'))).scans as number).toBe(
      PREMIUM_MONTHLY_SCANS,
    )
  })

  test('debits nothing once both are empty', async () => {
    await spend(user('u1'), PREMIUM_MONTHLY_SCANS)

    expect(await QuotaCommand.record(user('u1'), 'premium')).toEqual({ on: 'nothing' })
    expect((await QuotaQuery.ofCurrentMonth(user('u1'))).scans as number).toBe(
      PREMIUM_MONTHLY_SCANS,
    )
  })

  test('draws the granted balance down one scan at a time, whatever lands together', async () => {
    holdCredit(user('u1'))
    await spend(user('u1'), PREMIUM_MONTHLY_SCANS)
    await spend(user('u1'), 3)

    expect((await QuotaQuery.creditOf(user('u1'))).scans as number).toBe(HELD - 3)
  })
})

describe('the month s last scan, two landing together', () => {
  test('is taken once: the second draws on the granted scans', async () => {
    holdCredit(user('u1'))
    await spend(user('u1'), PREMIUM_MONTHLY_SCANS - 1)
    startFakeRequest()
    // Both requests checked the allowance before the model answered: one scan left in the month.
    await Promise.all([QuotaQuery.ofCurrentMonth(user('u1')), QuotaQuery.creditOf(user('u1'))])

    const debits = await spend(user('u1'), 2)

    expect(debits).toEqual([{ on: 'monthly' }, { on: 'credit' }])
    expect((await QuotaQuery.ofCurrentMonth(user('u1'))).scans as number).toBe(
      PREMIUM_MONTHLY_SCANS,
    )
    expect((await QuotaQuery.creditOf(user('u1'))).scans as number).toBe(HELD - 1)
  })

  test('costs two document reads per scan, both inside its one transaction', async () => {
    startFakeRequest()
    const [docReads, queryReads] = [fake.docReads, fake.queryReads]

    await QuotaCommand.record(user('u1'), 'premium')

    expect(fake.docReads - docReads).toBe(2)
    expect(fake.queryReads - queryReads).toBe(0)
    expect(fake.transactions).toHaveLength(1)
  })
})

describe('a granted balance', () => {
  test('reads as nothing left for an account that was never granted any', async () => {
    expect((await QuotaQuery.creditOf(user('u1'))).scans as number).toBe(0)
  })
})

describe('reading the allowance', () => {
  test('costs one document read per counter, however many times it is asked', async () => {
    await QuotaQuery.ofCurrentMonth(user('u1'))
    await QuotaQuery.ofCurrentMonth(user('u1'))
    await QuotaQuery.creditOf(user('u1'))
    await QuotaQuery.creditOf(user('u1'))

    expect(fake.docReads).toBe(2)
    expect(fake.queryReads).toBe(0)
  })

  test('sees a scan recorded earlier in the same request', async () => {
    await QuotaQuery.ofCurrentMonth(user('u1'))
    await QuotaCommand.record(user('u1'), 'premium')

    expect((await QuotaQuery.ofCurrentMonth(user('u1'))).scans as number).toBe(1)
  })

  test('sees a granted scan spent earlier in the same request', async () => {
    holdCredit(user('u1'))
    await spend(user('u1'), PREMIUM_MONTHLY_SCANS)
    await QuotaQuery.creditOf(user('u1'))

    await QuotaCommand.record(user('u1'), 'premium')

    expect((await QuotaQuery.creditOf(user('u1'))).scans as number).toBe(HELD - 1)
  })
})

describe('erasing an account', () => {
  test('takes the monthly counters and the granted balance with it', async () => {
    holdCredit(user('u1'))
    await QuotaCommand.record(user('u1'), 'premium')

    await QuotaCommand.deleteAllForUser(user('u1'))

    expect((await QuotaQuery.ofCurrentMonth(user('u1'))).scans as number).toBe(0)
    expect((await QuotaQuery.creditOf(user('u1'))).scans as number).toBe(0)
  })
})
