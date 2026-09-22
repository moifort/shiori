import { QuotaQuery } from '~/domain/quota/query'
import { builder } from '~/domain/shared/graphql/builder'
import { QuotaType } from './types'

builder.queryField('quota', (t) =>
  t.field({
    type: QuotaType,
    description:
      'This month’s scan allowance for the signed-in account. The scan screen reads it to show ' +
      'what is left, and the paywall to explain what a subscription lifts.\n\n' +
      '```graphql\n' +
      'query {\n' +
      '  quota {\n' +
      '    plan\n' +
      '    used\n' +
      '    limit\n' +
      '    remaining\n' +
      '    welcomeRemaining\n' +
      '    totalRemaining\n' +
      '    renewsOn\n' +
      '  }\n' +
      '}\n' +
      '```',
    resolve: (_root, _args, { userId }) => QuotaQuery.allowanceOf(userId),
  }),
)
