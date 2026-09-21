import { SeriesUseCase } from '~/domain/series/use-case'
import { builder } from '~/domain/shared/graphql/builder'

builder.mutationFields((t) => ({
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
