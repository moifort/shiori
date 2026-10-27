import { match, P } from 'ts-pattern'
import { NarratorCommand } from '~/domain/narrator/command'
import { NarratorPageType } from '~/domain/narrator/infrastructure/graphql/queries'
import type { NarratorCorrection } from '~/domain/narrator/types'
import { NarratorUseCase } from '~/domain/narrator/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { domainError, notFound } from '~/domain/shared/graphql/errors'
import { languageOf } from '~/domain/shared/language'

builder.mutationFields((t) => ({
  correctNarrator: t.field({
    type: NarratorPageType,
    description:
      'Correct what the world knows of a narrator, where the model or Wikipedia was ' +
      'wrong or found nothing. Omitted fields are left alone; one passed as null is ' +
      'cleared. Written into the shared entry, for every reader, and never written over ' +
      'by a later catalogue call or portrait lookup. Free: no model call.\n\n' +
      'Answers the narrator’s page as `narratorPage` with `waitForCatalogue: false` ' +
      'would. `NOT_FOUND` when the reader holds no recording of theirs; ' +
      '`PORTRAIT_NOT_AN_IMAGE` when `portraitUrl` does not serve an image.',
    args: {
      key: t.arg({ type: 'NarratorKey', required: true }),
      nationality: t.arg({ type: 'Nationality', required: false }),
      birthYear: t.arg({ type: 'Year', required: false }),
      deathYear: t.arg({ type: 'Year', required: false }),
      biography: t.arg({ type: 'NarratorBiography', required: false }),
      portraitUrl: t.arg({
        type: 'PortraitUrl',
        required: false,
        description: 'One `narratorPortraitChoices` offered, or an address the reader pasted.',
      }),
    },
    resolve: async (_root, { key, ...fields }, { userId, event }) => {
      // Omitted is left alone; null clears, which the command reads as undefined.
      const correction = Object.fromEntries(
        Object.entries(fields)
          .filter(([, value]) => value !== undefined)
          .map(([field, value]) => [field, value ?? undefined]),
      ) as NarratorCorrection
      return match(await NarratorUseCase.correct(userId, key, languageOf(event), correction))
        .with(null, () => notFound('Narrator not found'))
        .with('not-an-image', () =>
          domainError('PORTRAIT_NOT_AN_IMAGE', 'This address does not lead to an image'),
        )
        .with(P.not(P.string), (page) => page)
        .exhaustive()
    },
  }),
  setNarratorFavorite: t.boolean({
    description:
      'Heart a narrator, or take the heart back: the reader’s own, apart from the ' +
      'hearts their recordings carry, never shared. Answers what is now true. One write.',
    args: {
      key: t.arg({ type: 'NarratorKey', required: true }),
      favorite: t.arg.boolean({ required: true, description: 'True hearts, false takes it back' }),
    },
    resolve: (_root, args, { userId }) =>
      NarratorCommand.setFavorite(userId, args.key, args.favorite),
  }),
}))
