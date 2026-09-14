import { beforeEach, describe, expect, mock, test } from 'bun:test'
import type { UserId } from '~/domain/shared/types'
import { fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { FREE_MONTHLY_SCANS, WELCOME_SCANS } = await import('~/domain/quota/business-rules')
const { QuotaCommand } = await import('~/domain/quota/command')
const { QuotaQuery } = await import('~/domain/quota/query')

const user = (id: string) => id as UserId

let fake = resetFakeFirestore()

beforeEach(() => {
  fake = resetFakeFirestore()
})

const spend = (userId: UserId, times: number) =>
  Promise.all(Array.from({ length: times }, () => QuotaCommand.record(userId, 'free')))

describe('recording a scan', () => {
  test('starts a never-touched month at zero and counts the first scan', async () => {
    expect((await QuotaQuery.ofCurrentMonth(user('u1'))).scans as number).toBe(0)

    await QuotaCommand.record(user('u1'), 'free')

    expect((await QuotaQuery.ofCurrentMonth(user('u1'))).scans as number).toBe(1)
  })

  test('counts every scan that lands together, rather than losing one to a stale read', async () => {
    await spend(user('u1'), 3)

    expect((await QuotaQuery.ofCurrentMonth(user('u1'))).scans as number).toBe(3)
  })

  test('reads and writes the counter in one transaction, never as a bare set', async () => {
    await QuotaCommand.record(user('u1'), 'free')

    expect(fake.transactions).toHaveLength(1)
    expect(fake.directWrites).toHaveLength(0)
  })

  test('keeps one account out of another account s counter', async () => {
    await QuotaCommand.record(user('u1'), 'free')
    await QuotaCommand.record(user('u2'), 'free')
    await QuotaCommand.record(user('u2'), 'free')

    expect((await QuotaQuery.ofCurrentMonth(user('u1'))).scans as number).toBe(1)
    expect((await QuotaQuery.ofCurrentMonth(user('u2'))).scans as number).toBe(2)
  })
})

describe('which counter a scan is taken from', () => {
  test('spends the month first, leaving the granted scans untouched', async () => {
    await QuotaCommand.grantWelcomeCredit(user('u1'))

    expect(await QuotaCommand.record(user('u1'), 'free')).toEqual({ on: 'monthly' })
    expect((await QuotaQuery.creditOf(user('u1'))).scans).toBe(WELCOME_SCANS)
  })

  test('falls back to the granted scans once the month is spent', async () => {
    await QuotaCommand.grantWelcomeCredit(user('u1'))
    await spend(user('u1'), FREE_MONTHLY_SCANS)

    expect(await QuotaCommand.record(user('u1'), 'free')).toEqual({ on: 'credit' })
    expect((await QuotaQuery.creditOf(user('u1'))).scans as number).toBe(WELCOME_SCANS - 1)
    // The month stops where its limit is: the grant absorbs the overflow.
    expect((await QuotaQuery.ofCurrentMonth(user('u1'))).scans as number).toBe(FREE_MONTHLY_SCANS)
  })

  test('debits nothing once both are empty', async () => {
    await spend(user('u1'), FREE_MONTHLY_SCANS)

    expect(await QuotaCommand.record(user('u1'), 'free')).toEqual({ on: 'nothing' })
    expect((await QuotaQuery.ofCurrentMonth(user('u1'))).scans as number).toBe(FREE_MONTHLY_SCANS)
  })

  test('draws the granted balance down one scan at a time, whatever lands together', async () => {
    await QuotaCommand.grantWelcomeCredit(user('u1'))
    await spend(user('u1'), FREE_MONTHLY_SCANS)
    await spend(user('u1'), 3)

    expect((await QuotaQuery.creditOf(user('u1'))).scans as number).toBe(WELCOME_SCANS - 3)
  })
})

describe('granting the welcome scans', () => {
  test('hands a brand-new account its balance', async () => {
    await QuotaCommand.grantWelcomeCredit(user('u1'))

    expect((await QuotaQuery.creditOf(user('u1'))).scans).toBe(WELCOME_SCANS)
  })

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
    await QuotaCommand.record(user('u1'), 'free')

    expect((await QuotaQuery.ofCurrentMonth(user('u1'))).scans as number).toBe(1)
  })

  test('sees a granted scan spent earlier in the same request', async () => {
    await QuotaCommand.grantWelcomeCredit(user('u1'))
    await spend(user('u1'), FREE_MONTHLY_SCANS)
    await QuotaQuery.creditOf(user('u1'))

    await QuotaCommand.record(user('u1'), 'free')

    expect((await QuotaQuery.creditOf(user('u1'))).scans as number).toBe(WELCOME_SCANS - 1)
  })
})

describe('erasing an account', () => {
  test('takes the monthly counters and the granted balance with it', async () => {
    await QuotaCommand.grantWelcomeCredit(user('u1'))
    await QuotaCommand.record(user('u1'), 'free')

    await QuotaCommand.deleteAllForUser(user('u1'))

    expect((await QuotaQuery.ofCurrentMonth(user('u1'))).scans as number).toBe(0)
    expect((await QuotaQuery.creditOf(user('u1'))).scans as number).toBe(0)
  })
})
