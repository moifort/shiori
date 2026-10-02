import { match, P } from 'ts-pattern'
import { BookLanguageEnum } from '~/domain/book/infrastructure/graphql/enums'
import { SeriesType } from '~/domain/series/infrastructure/graphql/types'
import { SeriesUseCase } from '~/domain/series/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { badUserInput, notFound } from '~/domain/shared/graphql/errors'
import { languageOf } from '~/domain/shared/language'

builder.mutationFields((t) => ({
  refreshSeries: t.field({
    type: SeriesType,
    nullable: true,
    description:
      'Ask the world about a saga again: one fresh web-grounded model call, whose ' +
      'catalogue replaces the stored one of that edition for every reader of it. ' +
      'For a volume out since the catalogue was built.\n\n' +
      'Built as `series` builds a first catalogue: from a volume the reader holds, ' +
      'listing the volumes out in its language, `language` naming that edition ' +
      'when the saga is held in more than one. Takes a few seconds. Null when the ' +
      'reader holds no volume of the saga, and when the model failed or found no ' +
      'volumes — the previous catalogue is then kept as it was.',
    args: {
      seriesId: t.arg({ type: 'SeriesId', required: true }),
      language: t.arg({ type: BookLanguageEnum, required: false }),
    },
    resolve: (_root, args, { userId, event }) =>
      SeriesUseCase.recatalogue(
        userId,
        args.seriesId,
        languageOf(event),
        args.language ?? undefined,
      ),
  }),

  deleteSeries: t.int({
    description:
      'Remove a saga from the library: every volume the reader holds, or only the ' +
      'volumes of one edition when `language` names it — a saga held in two ' +
      'languages is two rows of the Series tab, removed apart. The rating and heart ' +
      'go with the last volume, since they are of the work rather than of an ' +
      'edition. The shared catalogue is left alone. Returns how many books were ' +
      'removed, zero when the reader held none.',
    args: {
      seriesId: t.arg({ type: 'SeriesId', required: true }),
      language: t.arg({
        type: BookLanguageEnum,
        required: false,
        description:
          'The edition to remove, for a saga held in more than one language. ' +
          'Absent, every edition goes.',
      }),
    },
    resolve: (_root, args, context) =>
      SeriesUseCase.removeFromLibrary(context.userId, args.seriesId, args.language ?? undefined),
  }),
  mergeSeries: t.int({
    description:
      'Fold a duplicate saga into the one the reader keeps: every volume they hold of ' +
      '`seriesId` — only those of one edition when `language` names it — is filed under ' +
      '`intoSeriesId` at its own number, under the name its volumes carry, and the ' +
      'duplicate leaves the library with its last volume, its rating and heart with it. ' +
      "The kept saga's opinion stands; the shared catalogues are left alone. Returns how " +
      'many books moved, zero when the reader held none of the duplicate.\n\n' +
      '`NOT_FOUND` when the reader holds no volume of the kept saga; `BAD_USER_INPUT` ' +
      'when both name the same saga, or when one is heard and the other read.',
    args: {
      seriesId: t.arg({ type: 'SeriesId', required: true, description: 'The duplicate.' }),
      language: t.arg({
        type: BookLanguageEnum,
        required: false,
        description:
          'The edition to move, for a duplicate held in more than one language. ' +
          'Absent, every edition moves.',
      }),
      intoSeriesId: t.arg({
        type: 'SeriesId',
        required: true,
        description: 'The saga the reader keeps.',
      }),
    },
    resolve: async (_root, args, context) =>
      match(
        await SeriesUseCase.mergeInto(
          context.userId,
          args.seriesId,
          args.language ?? undefined,
          args.intoSeriesId,
        ),
      )
        .with('not-found', () => notFound('Series not found'))
        .with('same-series', () => badUserInput('A saga cannot be merged into itself'))
        .with('other-format', () => badUserInput('A saga heard and a saga read cannot be merged'))
        .with(P.number, (moved) => moved)
        .exhaustive(),
  }),
}))
