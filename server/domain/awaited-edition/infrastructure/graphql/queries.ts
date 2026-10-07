import {
  AwaitedEditionType,
  EditionOfferType,
} from '~/domain/awaited-edition/infrastructure/graphql/types'
import { AwaitedEditionUseCase } from '~/domain/awaited-edition/use-case'
import {
  BookFormatEnum,
  BookLanguageEnum,
  heldAs,
} from '~/domain/book/infrastructure/graphql/enums'
import { ReleaseFormatEnum } from '~/domain/discovery/infrastructure/graphql/types'
import { builder } from '~/domain/shared/graphql/builder'
import { languageOf } from '~/domain/shared/language'

builder.queryFields((t) => ({
  awaitedEditions: t.field({
    type: [AwaitedEditionType],
    description:
      'The editions the reader awaits in one format: the ones out first, the newest ' +
      'first; then the ones announced, the soonest first; then the ones not announced, ' +
      'the latest awaited first. One the library now holds is no longer awaited and is ' +
      'left out.',
    args: { format: t.arg({ type: ReleaseFormatEnum, required: true }) },
    resolve: (_root, { format }, context) => AwaitedEditionUseCase.awaited(context.userId, format),
  }),
  bookEditionOffer: t.field({
    type: EditionOfferType,
    nullable: true,
    description:
      'What the page of one of the reader’s own books offers to await in the app’s ' +
      'language. Null for a book that is not theirs.',
    args: { bookId: t.arg({ type: 'BookId', required: true }) },
    resolve: (_root, { bookId }, context) =>
      AwaitedEditionUseCase.offerForBook(context.userId, bookId, languageOf(context.event)),
  }),
  draftEditionFormats: t.field({
    type: [ReleaseFormatEnum],
    description:
      'The formats a book not added yet — the one a scan proposes — may be awaited in, ' +
      'in the app’s language, once added: what its page will offer, so the review ' +
      'offers it before saving.',
    args: {
      language: t.arg({ type: BookLanguageEnum, required: true }),
      format: t.arg({ type: BookFormatEnum, required: true }),
    },
    resolve: (_root, { language, format }, context) =>
      AwaitedEditionUseCase.formatsForDraft(
        { language, format: heldAs(format).format ?? 'book' },
        languageOf(context.event),
      ),
  }),
}))
