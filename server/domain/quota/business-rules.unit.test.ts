import { describe, expect, it } from 'bun:test'
import {
  consumed,
  consumedCredit,
  debitFor,
  exhausted,
  FREE_MONTHLY_SCANS,
  freshQuota,
  limitOf,
  monthlyRemaining,
  monthOf,
  noCredit,
  PREMIUM_MONTHLY_SCANS,
  renewsOn,
  totalRemaining,
  WELCOME_SCANS,
  welcomeCredit,
} from '~/domain/quota/business-rules'
import { QuotaMonth } from '~/domain/quota/primitives'
import { Count, UserId } from '~/domain/shared/primitives'

const quotaOf = (scans: number) => ({
  ...freshQuota(UserId('u1'), QuotaMonth('2026-07')),
  scans: Count(scans),
})

const creditOf = (scans: number) => ({ ...noCredit(UserId('u1')), scans: Count(scans) })

const empty = noCredit(UserId('u1'))

describe('the month a scan counts against', () => {
  it('is the calendar month in UTC, so the window never moves with the caller', () => {
    expect(monthOf(new Date('2026-07-21T12:00:00.000Z')) as string).toBe('2026-07')
    expect(monthOf(new Date('2026-01-01T00:00:00.000Z')) as string).toBe('2026-01')
    expect(monthOf(new Date('2026-12-31T23:59:59.000Z')) as string).toBe('2026-12')
  })

  it('renews at midnight UTC on the 1st of the next month', () => {
    expect(renewsOn(QuotaMonth('2026-07'))).toEqual(new Date('2026-08-01T00:00:00.000Z'))
  })

  it('rolls December over into the next year', () => {
    expect(renewsOn(QuotaMonth('2026-12'))).toEqual(new Date('2027-01-01T00:00:00.000Z'))
  })
})

describe('what a plan allows in a month', () => {
  it('meters a free account', () => {
    expect(limitOf('free')).toBe(FREE_MONTHLY_SCANS)
  })

  it('leaves a subscriber a ceiling high enough never to meet it in normal use', () => {
    expect(limitOf('premium')).toBe(PREMIUM_MONTHLY_SCANS)
    expect(PREMIUM_MONTHLY_SCANS).toBeGreaterThan(FREE_MONTHLY_SCANS)
  })
})

describe('what is left this month', () => {
  it('starts at the full allowance', () => {
    expect(monthlyRemaining('free', quotaOf(0))).toBe(FREE_MONTHLY_SCANS)
  })

  it('goes down with each scan spent', () => {
    expect(monthlyRemaining('free', quotaOf(2))).toBe(Count(FREE_MONTHLY_SCANS - 2))
  })

  it('reads as zero rather than as a debt when the limit was lowered under the counter', () => {
    expect(monthlyRemaining('free', quotaOf(FREE_MONTHLY_SCANS + 10))).toBe(Count(0))
  })

  it('ignores the granted scans, which are not part of the month', () => {
    expect(monthlyRemaining('free', quotaOf(0))).toBe(FREE_MONTHLY_SCANS)
  })
})

describe('what a new account is granted', () => {
  it('holds the welcome scans, and nothing else', () => {
    expect(welcomeCredit(UserId('u1'))).toEqual({ userId: UserId('u1'), scans: WELCOME_SCANS })
  })

  it('is enough to stock a cellar, which the monthly allowance alone is not', () => {
    expect(WELCOME_SCANS).toBeGreaterThan(FREE_MONTHLY_SCANS)
  })

  it('reads as nothing left when the account was never granted any', () => {
    expect(empty.scans).toBe(Count(0))
  })
})

describe('everything that can still be scanned', () => {
  it('adds the granted scans to the month', () => {
    expect(totalRemaining('free', quotaOf(0), creditOf(20))).toBe(Count(FREE_MONTHLY_SCANS + 20))
  })

  it('is only the grant once the month is spent', () => {
    expect(totalRemaining('free', quotaOf(FREE_MONTHLY_SCANS), creditOf(20))).toBe(Count(20))
  })

  it('is only the month for an account holding no grant', () => {
    expect(totalRemaining('free', quotaOf(0), empty)).toBe(FREE_MONTHLY_SCANS)
  })
})

describe('which counter the next scan comes out of', () => {
  it('is the month while it still has room, so the one-off grant is not burned', () => {
    expect(debitFor('free', quotaOf(0), creditOf(20))).toEqual({ on: 'monthly' })
    expect(debitFor('free', quotaOf(FREE_MONTHLY_SCANS - 1), creditOf(20))).toEqual({
      on: 'monthly',
    })
  })

  it('is the grant once the month is spent', () => {
    expect(debitFor('free', quotaOf(FREE_MONTHLY_SCANS), creditOf(20))).toEqual({ on: 'credit' })
  })

  it('is nothing when both are empty', () => {
    expect(debitFor('free', quotaOf(FREE_MONTHLY_SCANS), empty)).toEqual({ on: 'nothing' })
  })
})

describe('whether the allowance is spent', () => {
  it('is not while a scan is left in the month', () => {
    expect(exhausted('free', quotaOf(FREE_MONTHLY_SCANS - 1), empty)).toBe(false)
  })

  it('is once the counter reaches the limit and nothing was granted', () => {
    expect(exhausted('free', quotaOf(FREE_MONTHLY_SCANS), empty)).toBe(true)
  })

  it('is not while granted scans are left, however spent the month is', () => {
    expect(exhausted('free', quotaOf(FREE_MONTHLY_SCANS), creditOf(1))).toBe(false)
  })

  it('is not for a subscriber at the free limit', () => {
    expect(exhausted('premium', quotaOf(FREE_MONTHLY_SCANS), empty)).toBe(false)
  })

  it('is for a subscriber past the abuse ceiling', () => {
    expect(exhausted('premium', quotaOf(PREMIUM_MONTHLY_SCANS), empty)).toBe(true)
  })
})

describe('spending a scan', () => {
  it('adds one to the counter and leaves the rest alone', () => {
    expect(consumed(quotaOf(2))).toEqual({
      userId: UserId('u1'),
      month: QuotaMonth('2026-07'),
      scans: Count(3),
    })
  })

  it('takes one off the granted balance', () => {
    expect(consumedCredit(creditOf(20))).toEqual({ userId: UserId('u1'), scans: Count(19) })
  })

  it('never draws the granted balance below zero', () => {
    expect(consumedCredit(creditOf(0))).toEqual({ userId: UserId('u1'), scans: Count(0) })
  })
})
