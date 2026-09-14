import { PlanEnum } from '~/domain/entitlement/infrastructure/graphql/enums'
import { limitOf, monthlyRemaining, renewsOn, totalRemaining } from '~/domain/quota/business-rules'
import type { Quota, ScanCredit } from '~/domain/quota/types'
import { builder } from '~/domain/shared/graphql/builder'
import type { Plan } from '~/domain/shared/types'

// What the `quota` query answers: the plan, this month's consumption under it,
// and the scans granted outside the month.
export type QuotaState = { plan: Plan; quota: Quota; credit: ScanCredit }

export const QuotaType = builder.objectRef<QuotaState>('Quota').implement({
  description:
    'The scan allowance: what the month holds, what was granted on top, what has been spent and ' +
    'when the month renews.\n\n' +
    'Only the AI scan is metered. Adding a bottle by hand, the cellar, tastings and sharing are ' +
    'unlimited on every plan, so a spent allowance never stops the app being used.',
  fields: (t) => ({
    plan: t.field({
      type: PlanEnum,
      description: 'The plan the allowance is read for, e.g. `FREE`',
      resolve: (state) => state.plan,
    }),
    used: t.int({
      description: 'How many scans were spent this month, e.g. `2`',
      resolve: (state) => state.quota.scans,
    }),
    limit: t.int({
      description: 'How many the plan allows in a month, e.g. `5`',
      resolve: (state) => limitOf(state.plan),
    }),
    remaining: t.int({
      description:
        'How many are left of the month, e.g. `3`. Never negative: an allowance already overspent ' +
        'reads as `0`. Ignores the granted scans — read `totalRemaining` for what can really be ' +
        'scanned.',
      resolve: (state) => monthlyRemaining(state.plan, state.quota),
    }),
    welcomeRemaining: t.int({
      description:
        'How many granted scans are left, e.g. `14`. Handed once when onboarding completes, drawn ' +
        'down only after the month is spent, and never refilled by the calendar.',
      resolve: (state) => state.credit.scans,
    }),
    totalRemaining: t.int({
      description:
        'Everything the account can still scan: the month plus what it was granted, e.g. `17`. ' +
        'This is the number a screen should show — the one the scan gate refuses at `0`.',
      resolve: (state) => totalRemaining(state.plan, state.quota, state.credit),
    }),
    renewsOn: t.field({
      type: 'DateTime',
      description:
        'When the counter goes back to zero: midnight UTC on the 1st of the next month, e.g. ' +
        '`"2026-08-01T00:00:00.000Z"`',
      resolve: (state) => renewsOn(state.quota.month),
    }),
  }),
})
