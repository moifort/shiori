import { QuotaMonth as toQuotaMonth } from '~/domain/quota/primitives'
import type { Quota, QuotaMonth, ScanCredit, ScanDebit } from '~/domain/quota/types'
import { Count } from '~/domain/shared/primitives'
import type { Count as CountType, Plan, UserId } from '~/domain/shared/types'

// What a free account gets each calendar month. The AI scan is the app's only
// variable cost, so this one number is the whole free tier: bottles, cellar,
// tastings and sharing stay unlimited, and a bottle can always be added by hand.
// Single source of truth — the GraphQL surface and the gate both read it here.
export const FREE_MONTHLY_SCANS: CountType = Count(5)

// A subscriber is not metered, but no single account may cost more than it pays:
// past this, a month's scans are refused as abuse rather than served at a loss.
// Sized so a month at the ceiling costs at most 70% of the cheapest plan's net
// proceeds (the annual one, ~1.48 EUR/month) at the current ~0.01 EUR scan cost,
// while staying far above real use: stocking a whole cellar is ~30 scans. To
// recalibrate when the scan cost changes, see docs/freemium-economics.md.
export const PREMIUM_MONTHLY_SCANS: CountType = Count(100)

// What a new account is handed when it finishes onboarding, once and for good.
// Stocking a whole cellar is ~30 scans, so five a month turns the first session
// into a wall before the app has shown what it does. Twenty covers a real
// stocking session without covering a whole cellar: the wall still arrives, but
// after the value rather than before it. Costs ~0.20 EUR per account created,
// once — see docs/freemium-economics.md.
export const WELCOME_SCANS: CountType = Count(20)

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

// The grant itself, handed once at the end of onboarding.
export const welcomeCredit = (userId: UserId): ScanCredit => ({ userId, scans: WELCOME_SCANS })

// How many scans the plan allows per month.
export const limitOf = (plan: Plan): CountType =>
  plan === 'premium' ? PREMIUM_MONTHLY_SCANS : FREE_MONTHLY_SCANS

// What is left of the month's allowance. Never negative: a limit lowered under an
// already-spent counter reads as zero, not as a debt.
export const monthlyRemaining = (plan: Plan, quota: Quota): CountType =>
  Count(Math.max(0, limitOf(plan) - quota.scans))

// Everything the account can still scan: the month plus what it was granted.
export const totalRemaining = (plan: Plan, quota: Quota, credit: ScanCredit): CountType =>
  Count(monthlyRemaining(plan, quota) + credit.scans)

// Which counter the next scan comes out of.
export const debitFor = (plan: Plan, quota: Quota, credit: ScanCredit): ScanDebit =>
  monthlyRemaining(plan, quota) > 0
    ? { on: 'monthly' }
    : credit.scans > 0
      ? { on: 'credit' }
      : { on: 'nothing' }

// Nothing left anywhere — the only state that refuses a scan.
export const exhausted = (plan: Plan, quota: Quota, credit: ScanCredit): boolean =>
  debitFor(plan, quota, credit).on === 'nothing'

// The quota once a scan has been spent.
export const consumed = (quota: Quota): Quota => ({ ...quota, scans: Count(quota.scans + 1) })

// The balance once a granted scan has been spent. Floored at zero: a balance
// drawn down concurrently must never read back as a debt.
export const consumedCredit = (credit: ScanCredit): ScanCredit => ({
  ...credit,
  scans: Count(Math.max(0, credit.scans - 1)),
})
