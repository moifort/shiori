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
      'A month whose selection ran out stays empty until the next: the model is asked ' +
      'only with `lookUp`, for a month that has no selection yet.',
    args: {
      format: t.arg({ type: ReleaseFormatEnum, required: true }),
      lookUp: t.arg.boolean({
        required: false,
        defaultValue: false,
        description:
          'Découvrir sets it: when the reader has no selection for this month, or one in ' +
          'another language, the model is asked for one — about a minute, never twice a ' +
          'day. Left out, the stored selection is read and nothing is asked.',
      }),
    },
    resolve: (_root, { format, lookUp }, context) =>
      SuggestionUseCase.monthly(context.userId, format, languageOf(context.event), lookUp ?? false),
  }),
}))
