import { match, P } from 'ts-pattern'
import { AwaitedEditionType } from '~/domain/awaited-edition/infrastructure/graphql/types'
import { AwaitedEditionUseCase, type AwaitOutcome } from '~/domain/awaited-edition/use-case'
import { ReleaseFormatEnum } from '~/domain/discovery/infrastructure/graphql/types'
import { builder } from '~/domain/shared/graphql/builder'
import { badUserInput, domainError, notFound } from '~/domain/shared/graphql/errors'
import { languageOf } from '~/domain/shared/language'

/** An awaited edition, or the error its outcome maps to. */
export const awaitedOrError = (outcome: AwaitOutcome) =>
  match(outcome)
    .with('not-found', () => notFound('No such book'))
    .with('not-awaitable', () => badUserInput('This book cannot be awaited in that format'))
    .with('too-many', () => domainError('TOO_MANY_AWAITED', 'Too many editions awaited'))
    .with({ id: P.string }, (view) => view)
    .exhaustive()

export const AWAIT_DESCRIPTION =
  'Look it up on the web at once when nobody did — one grounded call, about ten ' +
  'seconds — so the answer says whether it is announced or already out. Awaiting ' +
  'it twice answers the first. Fails with `BAD_USER_INPUT` for a format the book’s ' +
  'page does not offer, and `TOO_MANY_AWAITED` past a hundred editions.'

builder.mutationFields((t) => ({
  awaitBookEdition: t.field({
    type: AwaitedEditionType,
    description:
      'Await one of the reader’s own books in the language of the app, in one format: ' +
      `translated into print, or recorded. ${AWAIT_DESCRIPTION} \`NOT_FOUND\` for a ` +
      'book that is not theirs.',
    args: {
      bookId: t.arg({ type: 'BookId', required: true }),
      format: t.arg({ type: ReleaseFormatEnum, required: true }),
    },
    resolve: async (_root, { bookId, format }, context) =>
      awaitedOrError(
        await AwaitedEditionUseCase.awaitOwnBook(
          context.userId,
          bookId,
          format,
          languageOf(context.event),
        ),
      ),
  }),
  stopAwaitingEdition: t.boolean({
    description:
      'Stop awaiting an edition: no more searches for the reader, no alert. False ' +
      'when the reader awaits nothing by that id.',
    args: { id: t.arg({ type: 'AwaitedEditionId', required: true }) },
    resolve: (_root, { id }, context) => AwaitedEditionUseCase.stopAwaiting(context.userId, id),
  }),
}))
