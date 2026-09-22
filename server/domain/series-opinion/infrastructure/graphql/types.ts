import { BookLanguageEnum } from '~/domain/book/infrastructure/graphql/enums'
import type { SeriesOpinion } from '~/domain/series-opinion/types'
import { builder } from '~/domain/shared/graphql/builder'

export const SeriesOpinionType = builder.objectRef<SeriesOpinion>('SeriesOpinion').implement({
  description:
    "What one reader makes of one saga — never part of the saga's shared " +
    'catalogue, which is a fact about the world with no reader in it.\n\n' +
    'Held per saga, never per saga and language: the split the library draws by ' +
    'language is about editions on a shelf, and an opinion is about the work. ' +
    'Only following is told edition by edition, in `unfollowedLanguages`.',
  fields: (t) => ({
    seriesId: t.field({ type: 'SeriesId', resolve: (opinion) => opinion.seriesId }),
    rating: t.field({
      type: 'StarRating',
      nullable: true,
      description:
        "The reader's judgement of the saga itself, and deliberately not the " +
        'average of their volume ratings: a cycle can be worth more than its ' +
        'books, or rather less. Null until they rate it.',
      resolve: (opinion) => opinion.rating ?? null,
    }),
    favorite: t.boolean({
      description: 'A saga the reader keeps close. Independent of the rating.',
      resolve: (opinion) => opinion.favorite ?? false,
    }),
    followed: t.boolean({
      description:
        'Whether the reader follows the saga as a whole. True until they set it ' +
        'aside with `setSeriesFollowed` and no language, which makes every edition ' +
        '`UNFOLLOWED`. One edition set aside is in `unfollowedLanguages` instead.',
      resolve: (opinion) => opinion.unfollowed !== true,
    }),
    unfollowedLanguages: t.field({
      type: [BookLanguageEnum],
      description:
        'The editions set aside one by one, by language, while the saga as a ' +
        'whole is followed. Empty when none is.',
      resolve: (opinion) => opinion.unfollowedLanguages ?? [],
    }),
    volumeCount: t.field({
      type: 'VolumeNumber',
      nullable: true,
      description:
        "How many volumes the saga has by the reader's own count, set with " +
        '`declareSeriesVolumeCount`. Null until they say. Only read while nobody ' +
        'has catalogued the saga.',
      resolve: (opinion) => opinion.volumeCount ?? null,
    }),
  }),
})
