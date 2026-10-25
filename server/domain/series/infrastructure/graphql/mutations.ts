import { match, P } from 'ts-pattern'
import { BookLanguageEnum } from '~/domain/book/infrastructure/graphql/enums'
import {
  DEPRECATED_EDITION_LANGUAGE,
  SeriesType,
} from '~/domain/series/infrastructure/graphql/types'
import { seriesReferenceOf } from '~/domain/series/primitives'
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
    deprecationReason:
      'The saga page no longer offers it: a catalogue is completed by the release watch.',
    args: {
      seriesId: t.arg({ type: 'SeriesId', required: true }),
      language: t.arg({
        type: BookLanguageEnum,
        required: false,
        deprecationReason: DEPRECATED_EDITION_LANGUAGE,
      }),
    },
    resolve: (_root, args, { userId, event }) => {
      const { saga, language } = seriesReferenceOf(args.seriesId, args.language ?? undefined)
      return SeriesUseCase.recatalogue(userId, saga, languageOf(event), language)
    },
  }),

  deleteSeries: t.int({
    description:
      'Remove an edition of a saga from the library: every volume the reader holds ' +
      'of the edition `seriesId` names — a saga held in two languages is two rows ' +
      'of the Series tab, removed apart. A bare saga key, from an older build, ' +
      'removes every edition, or the one `language` names. The rating and heart ' +
      'go with the last volume, since they are of the work rather than of an ' +
      'edition. The shared catalogue is left alone. Returns how many books were ' +
      'removed, zero when the reader held none.',
    args: {
      seriesId: t.arg({ type: 'SeriesId', required: true }),
      language: t.arg({
        type: BookLanguageEnum,
        required: false,
        description: 'Beside a bare saga key: the edition to remove. Absent, every edition goes.',
        deprecationReason: DEPRECATED_EDITION_LANGUAGE,
      }),
    },
    resolve: (_root, args, context) => {
      const { saga, language } = seriesReferenceOf(args.seriesId, args.language ?? undefined)
      return SeriesUseCase.removeFromLibrary(context.userId, saga, language)
    },
  }),
  mergeSeries: t.int({
    description:
      'Fold a duplicate saga into the one the reader keeps: every volume they hold of ' +
      'the edition `seriesId` names — every edition for a bare saga key from an older ' +
      'build, or the one `language` names — is filed under the saga of ' +
      '`intoSeriesId`, in its own language, at its own number, under the name its volumes carry, and the ' +
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
        description: 'Beside a bare saga key: the edition to move. Absent, every edition moves.',
        deprecationReason: DEPRECATED_EDITION_LANGUAGE,
      }),
      intoSeriesId: t.arg({
        type: 'SeriesId',
        required: true,
        description: 'The saga the reader keeps.',
      }),
    },
    resolve: async (_root, args, context) => {
      const duplicate = seriesReferenceOf(args.seriesId, args.language ?? undefined)
      return match(
        await SeriesUseCase.mergeInto(
          context.userId,
          duplicate.saga,
          duplicate.language,
          seriesReferenceOf(args.intoSeriesId).saga,
        ),
      )
        .with('not-found', () => notFound('Series not found'))
        .with('same-series', () => badUserInput('A saga cannot be merged into itself'))
        .with('other-format', () => badUserInput('A saga heard and a saga read cannot be merged'))
        .with(P.number, (moved) => moved)
        .exhaustive()
    },
  }),
}))
