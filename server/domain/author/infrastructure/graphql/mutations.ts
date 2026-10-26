import { match, P } from 'ts-pattern'
import { AuthorCommand } from '~/domain/author/command'
import { AuthorCatalogueType, AuthorPageType } from '~/domain/author/infrastructure/graphql/queries'
import type { AuthorCorrection } from '~/domain/author/types'
import { AuthorUseCase } from '~/domain/author/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { domainError, notFound } from '~/domain/shared/graphql/errors'
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
  correctAuthor: t.field({
    type: AuthorPageType,
    description:
      'Correct what the world knows of an author, where the model or the portrait ' +
      'lookups were wrong or found nothing. Omitted fields are left alone; one passed ' +
      'as null is cleared. Written into the shared catalogue, for every reader, and ' +
      'never written over by a later catalogue call or portrait lookup. Free: no model ' +
      'call.\n\n' +
      'Answers the author’s page as `authorPage` with `waitForCatalogue: false` would. ' +
      '`NOT_FOUND` when the reader holds no book of the author; `PORTRAIT_NOT_AN_IMAGE` ' +
      'when `portraitUrl` does not serve an image.',
    args: {
      key: t.arg({ type: 'AuthorKey', required: true }),
      nationality: t.arg({ type: 'Nationality', required: false }),
      birthYear: t.arg({ type: 'Year', required: false }),
      deathYear: t.arg({ type: 'Year', required: false }),
      biography: t.arg({ type: 'AuthorBiography', required: false }),
      portraitUrl: t.arg({
        type: 'PortraitUrl',
        required: false,
        description: 'One `authorPortraitChoices` offered, or an address the reader pasted.',
      }),
    },
    resolve: async (_root, { key, ...fields }, { userId, event }) => {
      // Omitted is left alone; null clears, which the command reads as undefined.
      const correction = Object.fromEntries(
        Object.entries(fields)
          .filter(([, value]) => value !== undefined)
          .map(([field, value]) => [field, value ?? undefined]),
      ) as AuthorCorrection
      return match(await AuthorUseCase.correct(userId, key, languageOf(event), correction))
        .with(null, () => notFound('Author not found'))
        .with('not-an-image', () =>
          domainError('PORTRAIT_NOT_AN_IMAGE', 'This address does not lead to an image'),
        )
        .with(P.not(P.string), (page) => page)
        .exhaustive()
    },
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
