import { BookLanguageEnum } from '~/domain/book/infrastructure/graphql/enums'
import {
  AuthorReleasesType,
  DiscoveryType,
  ReleaseFormatEnum,
  SagaReleasesType,
} from '~/domain/discovery/infrastructure/graphql/types'
import { DiscoveryUseCase } from '~/domain/discovery/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { languageOf } from '~/domain/shared/language'

builder.queryFields((t) => ({
  discovery: t.field({
    type: DiscoveryType,
    description:
      'The Découvrir tab: every saga the reader follows in that format — all but the ones ' +
      'they set aside — with the next volume announced they do not hold, the soonest ' +
      'first, or a volume out in the last week they can have now; a saga with neither is ' +
      'left out. And every author they hold in that format with a work announced or just ' +
      'out outside those sagas.\n\n' +
      'Read off shared watches a scheduled pass keeps a week fresh, so it answers at once. ' +
      'A saga or an author never looked up is counted in `unwatched`, for `lookUpDiscovery`.',
    args: { format: t.arg({ type: ReleaseFormatEnum, required: true }) },
    resolve: (_root, { format }, context) =>
      DiscoveryUseCase.discover(context.userId, languageOf(context.event), format),
  }),
  sagaReleases: t.field({
    type: SagaReleasesType,
    description:
      'What the saga screen shows under its introduction: the next volume announced the ' +
      'reader does not hold, in the edition they opened. Empty, and not ' +
      '`watched`, for an edition nobody looked up yet: `lookUpSagaReleases` does.',
    args: {
      seriesId: t.arg({ type: 'SeriesId', required: true }),
      language: t.arg({ type: BookLanguageEnum, required: true }),
    },
    resolve: (_root, { seriesId, language }, context) =>
      DiscoveryUseCase.sagaReleases(context.userId, seriesId, language),
  }),
  authorReleases: t.field({
    type: AuthorReleasesType,
    description:
      'What the author page shows under its heading, in one format: the soonest work ' +
      'announced and the ones out in the last three months, outside the sagas the reader ' +
      'holds — the Découvrir Authors shelf’s row for that author. Empty for an author the ' +
      'reader holds nothing of in that format, or never looked up yet.',
    args: {
      key: t.arg({ type: 'AuthorKey', required: true }),
      format: t.arg({ type: ReleaseFormatEnum, required: true }),
    },
    resolve: (_root, { key, format }, context) =>
      DiscoveryUseCase.authorReleases(context.userId, key, format),
  }),
}))
