import type { Brand } from 'ts-brand'
import type { Count, UserId } from '~/domain/shared/types'

/** The calendar month a quota counts for, `"2026-07"`. The window IS the month:
 *  the counter never resets, the next month simply gets its own document. */
export type QuotaMonth = Brand<string, 'QuotaMonth'>

/** One account's AI consumption for one month. Absent storage means a fresh
 *  month, which reads back as a counter at zero (see the repository).
 *
 *  A scan is the app's only variable cost, so it is the only thing counted. */
export type Quota = {
  userId: UserId
  month: QuotaMonth
  scans: Count
}

/** Scans granted outside the monthly allowance, as a balance that is drawn down
 *  and never refilled by the calendar. One grant per account, at the end of
 *  onboarding: stocking a cellar is the moment the app is judged, and metering
 *  it at five would have made that judgement about the meter.
 *
 *  Absent storage means nothing left, the same way an absent quota reads zero. */
export type ScanCredit = {
  userId: UserId
  scans: Count
}

/** Which counter the next scan comes out of. The month goes first because it
 *  refills on the 1st and the grant never does — spending the grant while the
 *  month still had room would quietly burn a one-off on a scan that was free. */
export type ScanDebit = { on: 'monthly' } | { on: 'credit' } | { on: 'nothing' }
