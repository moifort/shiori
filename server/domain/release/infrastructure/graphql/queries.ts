import { CoverChoiceType } from '~/domain/book/infrastructure/graphql/types'
import { ReleaseUseCase } from '~/domain/release/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { notFound } from '~/domain/shared/graphql/errors'

builder.queryFields((t) => ({
  releaseCoverChoices: t.field({
    type: [CoverChoiceType],
    description:
      'The covers any reader may pick for a book they do not hold, for ' +
      '`chooseReleaseCover`: `drawn`, the cover its page draws now, first, then what the ' +
      'release knows — a cover picked before, the edition’s, its descriptions’ — and what ' +
      'Amazon and Open Library have for its ISBN and for up to three other editions in its ' +
      'language. Each image once. Free: no model call, no scan spent; a source that does not ' +
      'answer within a few seconds is a cover not offered. NOT_FOUND while no page of the ' +
      'release was ever described.',
    args: {
      key: t.arg.string({ required: true, description: '`Release.key`.' }),
      drawn: t.arg({ type: 'CoverUrl', required: false }),
    },
    resolve: async (_root, args) => {
      const choices = await ReleaseUseCase.coverChoices(args.key, args.drawn ?? undefined)
      return choices === 'not-found' ? notFound('Release not found') : choices
    },
  }),
}))
