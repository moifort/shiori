import { QuotaMonth as toQuotaMonth } from '~/domain/quota/primitives'
import type { Quota, QuotaMonth, ScanCredit, ScanDebit } from '~/domain/quota/types'
import { Count } from '~/domain/shared/primitives'
import type { Count as CountType, Plan, UserId } from '~/domain/shared/types'

// What an account without Premium gets each calendar month: nothing, since 2026-11-25.
// Shiori has no free plan: a new reader starts a free trial, which is Premium, and an
// account whose trial or subscription ended is offered one again. Kept as a number
// because builds on sale read it to draw their gauge, and an empty gauge is what sends
// them to the offer. Single source of truth — the GraphQL surface and the gate read it.
export const FREE_MONTHLY_SCANS: CountType = Count(0)

// What one scan costs, in euros, as measured on the bill (see docs/freemium-economics.md,
// measured 2026-11-25 on the October 2026 billing export and AI-usage counters). A scan runs
// grounded lookups (enrichment, plus a series and an author when they are new), so its cost
// depends on whether the month's 5,000 free Google searches are spent:
// - `withFreeSearches`: October's Gemini bill shared by its scans, ~0.034.
// - `allSearchesPaid`: one book added once every search is paid (2026-10-17), ~0.15; the
//   Claude Haiku fallback that takes over past the free searches costs the same order.
// Estimates, not invoices per scan: recalibrate here when the bill moves.
export const SCAN_COST_EUR = { withFreeSearches: 0.03, allSearchesPaid: 0.15 } as const

// A subscriber is not metered in what the app shows, but no single account may cost more
// than it pays: past this, a month's scans are refused rather than served at a loss.
// Thirty since 2026-11-25, down from 100: the yearly plan nets ~2.07 EUR a month after VAT
// and the store's 15% (docs/freemium-economics.md), and a month at the ceiling costs 0.90 EUR
// while the free searches last, 4.50 EUR once they are spent. A reader adds five to ten
// printed books a month; Kindle and Audible imports cost no scan and are not counted.
export const PREMIUM_MONTHLY_SCANS: CountType = Count(30)

// What an account is handed at its first paid Premium period, once and for good, on top of
// whatever it still holds. Subscribing is when a reader brings in the printed library rather
// than a shelf, and the monthly ceiling alone would refuse that evening. Two hundred since
// 2026-11-25, down from 500: 6 to 30 EUR at SCAN_COST_EUR, against 24.78 EUR netted by a
// first year, where 500 could cost three years of it.
export const PREMIUM_WELCOME_SCANS: CountType = Count(200)

// The month a moment belongs to, `"2026-07"`. UTC on purpose: the window must not
// move with the caller's timezone, and someone scanning near midnight on the 1st
// is a rounding question nobody will ever ask.
export const monthOf = (moment: Date): QuotaMonth =>
  toQuotaMonth(`${moment.getUTCFullYear()}-${String(moment.getUTCMonth() + 1).padStart(2, '0')}`)

// When the counter goes back to zero: midnight UTC on the 1st of the next month.
// `Date.UTC` rolls December over to January on its own.
export const renewsOn = (month: QuotaMonth): Date => {
  const [year, index] = (month as string).split('-').map(Number)
  return new Date(Date.UTC(year as number, index as number, 1))
}

// A month nobody has spent anything in yet — what an absent document means.
export const freshQuota = (userId: UserId, month: QuotaMonth): Quota => ({
  userId,
  month,
  scans: Count(0),
})

// An account holding no granted scans — what an absent document means.
export const noCredit = (userId: UserId): ScanCredit => ({ userId, scans: Count(0) })

// The balance once the Premium welcome is handed, or nothing when the account
// already had it: renewing, cancelling and subscribing again never hand it twice.
export const withPremiumWelcome = (credit: ScanCredit, now: Date): ScanCredit | undefined =>
  credit.premiumWelcomedAt
    ? undefined
    : { ...credit, scans: Count(credit.scans + PREMIUM_WELCOME_SCANS), premiumWelcomedAt: now }

// How many scans the plan allows per month.
export const limitOf = (plan: Plan): CountType =>
  plan === 'premium' ? PREMIUM_MONTHLY_SCANS : FREE_MONTHLY_SCANS

// What is left of the month's allowance. Never negative: a limit lowered under an
// already-spent counter reads as zero, not as a debt.
export const monthlyRemaining = (plan: Plan, quota: Quota): CountType =>
  Count(Math.max(0, limitOf(plan) - quota.scans))

// Everything the account can still scan: the month plus what it was granted, for a
// subscriber. Nothing without Premium: the scans it was granted wait for its subscription,
// and the gate refuses at zero, so a gauge must not show them as available.
export const totalRemaining = (plan: Plan, quota: Quota, credit: ScanCredit): CountType =>
  plan === 'premium' ? Count(monthlyRemaining(plan, quota) + credit.scans) : Count(0)

// Which counter the next scan comes out of.
export const debitFor = (plan: Plan, quota: Quota, credit: ScanCredit): ScanDebit =>
  monthlyRemaining(plan, quota) > 0
    ? { on: 'monthly' }
    : credit.scans > 0
      ? { on: 'credit' }
      : { on: 'nothing' }

// Nothing a scan may be taken from: no Premium (there is no free plan, and the scans an
// account was granted wait for its subscription), or nothing left anywhere.
export const exhausted = (plan: Plan, quota: Quota, credit: ScanCredit): boolean =>
  plan !== 'premium' || debitFor(plan, quota, credit).on === 'nothing'

// The quota once a scan has been spent.
export const consumed = (quota: Quota): Quota => ({ ...quota, scans: Count(quota.scans + 1) })

// The balance once a granted scan has been spent. Floored at zero: a balance
// drawn down concurrently must never read back as a debt.
export const consumedCredit = (credit: ScanCredit): ScanCredit => ({
  ...credit,
  scans: Count(Math.max(0, credit.scans - 1)),
})

// Why a scan is refused, for the log that counts refusals: no subscription, or a subscriber
// with nothing left.
export const refusalOf = (plan: Plan): 'no-subscription' | 'allowance-spent' =>
  plan === 'premium' ? 'allowance-spent' : 'no-subscription'
