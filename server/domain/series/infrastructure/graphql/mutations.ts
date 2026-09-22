import { BookLanguageEnum } from '~/domain/book/infrastructure/graphql/enums'
import { SeriesType } from '~/domain/series/infrastructure/graphql/types'
import { SeriesUseCase } from '~/domain/series/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { languageOf } from '~/domain/shared/language'

builder.mutationFields((t) => ({
  refreshSeries: t.field({
    type: SeriesType,
    nullable: true,
    description:
      'Ask the world about a saga again: one fresh web-grounded model call, whose ' +
      'catalogue replaces the stored one for every reader of the saga. For a volume ' +
      'announced since the catalogue was built, or a catalogue built in the wrong ' +
      'language.\n\n' +
      'Built as `series` builds a first catalogue: from a volume the reader holds, ' +
      'titled as the edition on the shelf titles it, `language` naming that edition ' +
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
      'Remove a saga from the library: every volume the reader holds, and their ' +
      'rating and heart for it. The shared catalogue is left alone. Returns how many ' +
      'books were removed, zero when the reader held none.',
    args: { seriesId: t.arg({ type: 'SeriesId', required: true }) },
    resolve: (_root, args, context) =>
      SeriesUseCase.removeFromLibrary(context.userId, args.seriesId),
  }),
}))
