import { EntitlementQuery } from '~/domain/entitlement/query'
import { builder } from '~/domain/shared/graphql/builder'
import { EntitlementType } from './types'

builder.queryField('entitlement', (t) =>
  t.field({
    type: EntitlementType,
    description:
      'What the account is entitled to today, and the account token to start a purchase with. ' +
      'The app reads this before showing the subscription sheet.\n\n' +
      '```graphql\n' +
      'query {\n' +
      '  entitlement {\n' +
      '    plan\n' +
      '    appAccountToken\n' +
      '    productId\n' +
      '    expiresOn\n' +
      '  }\n' +
      '}\n' +
      '```',
    resolve: async (_root, _args, { userId }) => ({
      plan: await EntitlementQuery.planOf(userId),
      appAccountToken: EntitlementQuery.tokenFor(userId) as string,
      entitlement: await EntitlementQuery.of(userId),
    }),
  }),
)
