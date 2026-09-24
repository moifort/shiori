import { DiscoverType } from '~/domain/discover/infrastructure/graphql/types'
import { DiscoverUseCase } from '~/domain/discover/use-case'
import { ScanResultType } from '~/domain/scan/infrastructure/graphql/types'
import { builder } from '~/domain/shared/graphql/builder'
import { languageOf } from '~/domain/shared/language'

builder.queryField('discover', (t) =>
  t.field({
    type: DiscoverType,
    description:
      'The Découvrir tab. Opening it the first time enrols the reader in the ' +
      'daily refresh; until that has run, only what earlier readers of the same ' +
      'sagas and books already found is there.',
    resolve: (_root, _args, context) =>
      DiscoverUseCase.discover(context.userId, languageOf(context.event)),
  }),
)

builder.queryField('bookPreview', (t) =>
  t.field({
    type: ScanResultType,
    nullable: true,
    description:
      'A book of the Découvrir tab the reader does not hold, built whole as a scan ' +
      'builds one — cover, summary, genre, publisher, pages — so the app draws it with ' +
      'the book screen itself. Works for a book not out yet, described from its ' +
      'announcement; what nobody knows before release is absent.\n\n' +
      'Shared and kept: the first reader to open a book pays the model call, a few ' +
      'seconds, and every later opening is instant. Spends no scan of the allowance. ' +
      'Only for an edition a release watch found — `releaseKey` is the `Release.key` ' +
      'and `title` the `ReleaseEdition.title` — and null for any other, or when the ' +
      'model failed on a book never built.',
    args: {
      releaseKey: t.arg.string({ required: true }),
      title: t.arg({ type: 'BookTitle', required: true }),
    },
    resolve: (_root, { releaseKey, title }, context) =>
      DiscoverUseCase.preview(releaseKey, title, languageOf(context.event)),
  }),
)
