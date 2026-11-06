import { match, P } from 'ts-pattern'
import { EntitlementQuery } from '~/domain/entitlement/query'
import { EntitlementUseCase } from '~/domain/entitlement/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { domainError } from '~/domain/shared/graphql/errors'
import { EntitlementType } from './types'

builder.mutationField('syncEntitlement', (t) =>
  t.field({
    type: EntitlementType,
    description:
      'Hand over a transaction the App Store signed: after a purchase, after a restore, and on ' +
      'every launch while a subscription is running.\n\n' +
      'The signature is verified against Apple’s root certificates and the purchase must carry ' +
      'this account’s `appAccountToken`, so this is what grants Premium: nothing else does.\n\n' +
      'Fails with `INVALID_TRANSACTION` when the signature does not check out, and ' +
      '`TRANSACTION_NOT_YOURS` when the purchase belongs to another account.\n\n' +
      '```graphql\n' +
      'mutation {\n' +
      '  syncEntitlement(signedTransaction: "eyJhbGciOi...") {\n' +
      '    plan\n' +
      '    expiresOn\n' +
      '  }\n' +
      '}\n' +
      '```',
    args: {
      signedTransaction: t.arg.string({
        required: true,
        description:
          'The JWS representation of the StoreKit transaction, e.g. the `jwsRepresentation` of ' +
          'a verified entitlement',
      }),
    },
    resolve: async (_root, { signedTransaction }, { userId }) => {
      const result = await EntitlementUseCase.sync(userId, signedTransaction)
      return match(result)
        .with('invalid-transaction', () =>
          domainError('INVALID_TRANSACTION', 'The App Store did not sign this transaction'),
        )
        .with('transaction-not-yours', () =>
          domainError('TRANSACTION_NOT_YOURS', 'This purchase belongs to another account'),
        )
        .with(P.not(P.string), async (entitlement) => ({
          plan: await EntitlementQuery.planOf(userId),
          appAccountToken: entitlement.appAccountToken as string,
          entitlement,
        }))
        .exhaustive()
    },
  }),
)

builder.mutationField('syncPlayEntitlement', (t) =>
  t.field({
    type: EntitlementType,
    description:
      'Hand over a Google Play subscription purchase: after a purchase, after a restore, and on ' +
      'every launch of the Android app while a subscription is running.\n\n' +
      'Google is asked what the token bought, and the purchase must carry this account’s ' +
      '`appAccountToken` as its obfuscated account id, so this is what grants Premium on ' +
      'Android: nothing else does. The purchase is acknowledged to Google once recorded.\n\n' +
      'Fails with `INVALID_TRANSACTION` when Google does not know the token, and ' +
      '`TRANSACTION_NOT_YOURS` when the purchase belongs to another account.\n\n' +
      '```graphql\n' +
      'mutation {\n' +
      '  syncPlayEntitlement(purchaseToken: "opaque-token-from-play-billing") {\n' +
      '    plan\n' +
      '    expiresOn\n' +
      '  }\n' +
      '}\n' +
      '```',
    args: {
      purchaseToken: t.arg.string({
        required: true,
        description:
          'The purchase token Play Billing handed the app for the subscription, e.g. ' +
          '`Purchase.purchaseToken`',
      }),
    },
    resolve: async (_root, { purchaseToken }, { userId }) => {
      const result = await EntitlementUseCase.syncPlay(userId, purchaseToken)
      return match(result)
        .with('invalid-transaction', () =>
          domainError('INVALID_TRANSACTION', 'Google Play does not know this purchase'),
        )
        .with('transaction-not-yours', () =>
          domainError('TRANSACTION_NOT_YOURS', 'This purchase belongs to another account'),
        )
        .with(P.not(P.string), async (entitlement) => ({
          plan: await EntitlementQuery.planOf(userId),
          appAccountToken: entitlement.appAccountToken as string,
          entitlement,
        }))
        .exhaustive()
    },
  }),
)
