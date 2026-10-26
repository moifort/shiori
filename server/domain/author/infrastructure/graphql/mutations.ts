import { AuthorCommand } from '~/domain/author/command'
import { AuthorCatalogueType } from '~/domain/author/infrastructure/graphql/queries'
import { AuthorUseCase } from '~/domain/author/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { languageOf } from '~/domain/shared/language'

builder.mutationFields((t) => ({
  refreshAuthor: t.field({
    type: AuthorCatalogueType,
    nullable: true,
    description:
      'Ask the world about an author again: one fresh web-grounded model call, whose ' +
      'catalogue replaces the stored one for every reader. An author the model could ' +
      'not describe on their first opening is never asked about again otherwise.\n\n' +
      'Takes a few seconds. Null when the reader holds no book of the author, and when ' +
      'the model failed or found nothing — the previous catalogue is then kept.',
    deprecationReason: 'The author page no longer offers it.',
    args: { key: t.arg({ type: 'AuthorKey', required: true }) },
    resolve: (_root, args, { userId, event }) =>
      AuthorUseCase.recatalogue(userId, args.key, languageOf(event)),
  }),
  setAuthorFavorite: t.boolean({
    description:
      'Heart an author, or take the heart back: the reader own, apart from the hearts ' +
      'their books carry, never shared. Answers what is now true. One write.',
    args: {
      key: t.arg({ type: 'AuthorKey', required: true }),
      favorite: t.arg.boolean({ required: true, description: 'True hearts, false takes it back' }),
    },
    resolve: (_root, args, { userId }) =>
      AuthorCommand.setFavorite(userId, args.key, args.favorite),
  }),
}))
