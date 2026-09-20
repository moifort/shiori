import type { SeriesOpinion } from '~/domain/series-opinion/types'
import { builder } from '~/domain/shared/graphql/builder'

export const SeriesOpinionType = builder.objectRef<SeriesOpinion>('SeriesOpinion').implement({
  description:
    "What one reader makes of one saga — never part of the saga's shared " +
    'catalogue, which is a fact about the world with no reader in it.\n\n' +
    'Held per saga, never per saga and language: the split the library draws by ' +
    'language is about editions on a shelf, and an opinion is about the work.',
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
  }),
})
