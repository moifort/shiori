import { DiscoverType } from '~/domain/discover/infrastructure/graphql/types'
import { DiscoverUseCase } from '~/domain/discover/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { languageOf } from '~/domain/shared/language'

builder.mutationFields((t) => ({
  refreshDiscover: t.field({
    type: DiscoverType,
    description:
      'Look for translations now rather than waiting for the daily refresh. Granted ' +
      'once a day; past that it answers the tab as it stands. Slow — grounded model ' +
      'calls and an Audible search per author — so the app waits with a loader.',
    resolve: (_root, _args, context) =>
      DiscoverUseCase.refreshOnDemand(context.userId, languageOf(context.event)),
  }),

  dismissTranslation: t.boolean({
    description:
      '"Pas intéressé": never propose this work again, nor alert about it. Answers ' +
      'false before the tab was ever opened.',
    args: { key: t.arg.string({ required: true }) },
    resolve: (_root, args, context) => DiscoverUseCase.dismiss(context.userId, args.key),
  }),
}))
