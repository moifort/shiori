import { DashboardType } from '~/domain/analytics/infrastructure/graphql/types'
import { AnalyticsUseCase } from '~/domain/analytics/use-case'
import { builder } from '~/domain/shared/graphql/builder'

builder.queryField('dashboard', (t) =>
  t.field({
    type: DashboardType,
    description:
      'The home dashboard of the signed-in reader.\n\n' +
      'Pass the device time zone: every day, month and year is counted in it.\n\n' +
      '```graphql\n' +
      'query {\n' +
      '  dashboard(timeZone: "Europe/Paris") {\n' +
      '    booksPerYear { year count }\n' +
      '    reading { id title coverUrl startedAt }\n' +
      '    pagesPerDay { current previous }\n' +
      '  }\n' +
      '}\n' +
      '```',
    args: { timeZone: t.arg({ type: 'TimeZone', required: true }) },
    resolve: (_root, args, { userId }) => AnalyticsUseCase.dashboard(userId, args.timeZone),
  }),
)
