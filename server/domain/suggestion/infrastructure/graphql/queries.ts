import { ReleaseFormatEnum } from '~/domain/discovery/infrastructure/graphql/types'
import { builder } from '~/domain/shared/graphql/builder'
import { languageOf } from '~/domain/shared/language'
import { MonthlyDiscoveriesType } from '~/domain/suggestion/infrastructure/graphql/types'
import { SuggestionUseCase } from '~/domain/suggestion/use-case'

builder.queryFields((t) => ({
  monthlyDiscoveries: t.field({
    type: MonthlyDiscoveriesType,
    description:
      'The discoveries of the month: five books chosen for the reader from their hearts, ' +
      'stars, drops and dismissals, each with why, in one format and the app’s language.\n\n' +
      'The model is asked when the month has no selection yet or fewer than five are left, ' +
      'at most once a day: that answer takes about a minute. Every other one reads the ' +
      'stored selection.',
    args: { format: t.arg({ type: ReleaseFormatEnum, required: true }) },
    resolve: (_root, { format }, context) =>
      SuggestionUseCase.monthly(context.userId, format, languageOf(context.event)),
  }),
}))
