import { PlanEnum } from '~/domain/entitlement/infrastructure/graphql/enums'
import type { Entitlement } from '~/domain/entitlement/types'
import { builder } from '~/domain/shared/graphql/builder'
import type { Plan } from '~/domain/shared/types'

// What the `entitlement` query answers. The plan is the decided answer; the rest
// exists so the app can start a purchase and show what is running.
export type EntitlementState = {
  plan: Plan
  appAccountToken: string
  entitlement?: Entitlement
}

export const EntitlementType = builder.objectRef<EntitlementState>('Entitlement').implement({
  description:
    'What the account is entitled to, and what the App Store sold to get there.\n\n' +
    'Read it before starting a purchase: `appAccountToken` is what ties the payment back to ' +
    'this account, and a purchase made without it cannot be matched to anyone.',
  fields: (t) => ({
    plan: t.field({
      type: PlanEnum,
      description: 'The plan in force right now, e.g. `PREMIUM`',
      resolve: (state) => state.plan,
    }),
    appAccountToken: t.exposeString('appAccountToken', {
      description:
        'The UUID to pass to StoreKit as the purchase’s account token, e.g. ' +
        '`"20099a54-f027-5426-b2f0-79d90a5050f1"`. Without it a purchase cannot be matched to ' +
        'this account, and syncing it will be refused.',
    }),
    productId: t.string({
      nullable: true,
      description:
        'The subscription bought, e.g. `"com.polyforms.vinarium.app.premium.yearly"` — null ' +
        'when there is none',
      resolve: (state) => state.entitlement?.productId ?? null,
    }),
    expiresOn: t.field({
      type: 'DateTime',
      nullable: true,
      description:
        'When the paid period ends, e.g. `"2027-07-21T09:12:00.000Z"` — null when there is no ' +
        'subscription. A cancelled subscription keeps its Premium until this date.',
      resolve: (state) => state.entitlement?.expiresAt ?? null,
    }),
  }),
})
