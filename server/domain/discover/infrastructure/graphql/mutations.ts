import { match } from 'ts-pattern'
import { BookType } from '~/domain/book/infrastructure/graphql/types'
import { BookQuery } from '~/domain/book/query'
import { DiscoverType } from '~/domain/discover/infrastructure/graphql/types'
import { DiscoverUseCase } from '~/domain/discover/use-case'
import { CopiedStatusEnum } from '~/domain/friendship/infrastructure/graphql/enums'
import { builder } from '~/domain/shared/graphql/builder'
import { domainError, notFound } from '~/domain/shared/graphql/errors'
import { languageOf } from '~/domain/shared/language'

builder.mutationFields((t) => ({
  refreshDiscover: t.field({
    type: DiscoverType,
    description:
      'Prepare the Découvrir shelves now rather than waiting for the weekly ' +
      'refresh. Granted once a day; past that it answers the tab as it stands. ' +
      'Slow — several grounded model calls — so the app waits with a loader.',
    resolve: (_root, _args, context) =>
      DiscoverUseCase.refreshOnDemand(context.userId, languageOf(context.event)),
  }),

  dismissSuggestion: t.boolean({
    description:
      '"Pas pour moi": never propose this book again, and let the next refresh ' +
      'know. Answers false before the tab was ever opened.',
    args: { key: t.arg.string({ required: true }) },
    resolve: (_root, args, context) => DiscoverUseCase.dismiss(context.userId, args.key),
  }),

  addSuggestion: t.field({
    type: BookType,
    description:
      'Put a suggestion on the reader’s shelf, on the pile or among the books ' +
      'read. The client names it by its key; the book is made from what the tab ' +
      'stored. Fails with `NOT_FOUND` for a key the tab does not hold and ' +
      '`ALREADY_IN_LIBRARY` for a story the reader owns.',
    args: {
      key: t.arg.string({ required: true }),
      status: t.arg({ type: CopiedStatusEnum, required: true }),
    },
    resolve: async (_root, args, context) => {
      const outcome = await DiscoverUseCase.addSuggestion(context.userId, args.key, args.status)
      return match(outcome)
        .with('not-found', () => notFound('Suggestion not found'))
        .with('already-owned', () =>
          domainError('ALREADY_IN_LIBRARY', 'That book is already in your library'),
        )
        .otherwise(async (book) => (await BookQuery.withSignedCovers([book]))[0])
    },
  }),
}))
