import { AwardShelfType } from '~/domain/award/infrastructure/graphql/types'
import { AwardUseCase } from '~/domain/award/use-case'
import { GenreEnum } from '~/domain/book/infrastructure/graphql/enums'
import { ReleaseFormatEnum } from '~/domain/discovery/infrastructure/graphql/types'
import { builder } from '~/domain/shared/graphql/builder'
import { languageOf } from '~/domain/shared/language'

builder.queryFields((t) => ({
  awardShelf: t.field({
    type: AwardShelfType,
    nullable: true,
    description:
      'The novels the literary awards of the reader’s genre crowned — Hugo, Nebula, ' +
      'Locus, Clarke, World Fantasy — in one format, with where their edition stands in ' +
      'the app’s language. The genre is the one asked for when the reader reads it ' +
      'enough, else the one they read most. Null when they read no genre with awards ' +
      'enough.\n\n' +
      'Read off shared watches a scheduled pass looks up, so it answers at once: a novel ' +
      'never looked up comes back not `watched`.',
    args: {
      format: t.arg({ type: ReleaseFormatEnum, required: true }),
      genre: t.arg({ type: GenreEnum, required: false }),
    },
    resolve: (_root, { format, genre }, context) =>
      AwardUseCase.shelf(context.userId, format, languageOf(context.event), genre ?? undefined),
  }),
}))
