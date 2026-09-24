import { DiscoverType } from '~/domain/discover/infrastructure/graphql/types'
import { DiscoverUseCase } from '~/domain/discover/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { languageOf } from '~/domain/shared/language'

builder.queryField('discover', (t) =>
  t.field({
    type: DiscoverType,
    description:
      'The Découvrir tab. Opening it the first time enrols the reader in the ' +
      'daily refresh; until that has run, only what earlier readers of the same ' +
      'books already found is there.',
    resolve: (_root, _args, context) =>
      DiscoverUseCase.discover(context.userId, languageOf(context.event)),
  }),
)
