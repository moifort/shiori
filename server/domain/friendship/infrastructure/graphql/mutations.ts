import { match } from 'ts-pattern'
import { BookType } from '~/domain/book/infrastructure/graphql/types'
import { BookQuery } from '~/domain/book/query'
import { FriendshipCommand } from '~/domain/friendship/command'
import { CopiedStatusEnum } from '~/domain/friendship/infrastructure/graphql/enums'
import { FriendInvitationType, FriendType } from '~/domain/friendship/infrastructure/graphql/types'
import { FriendshipUseCase } from '~/domain/friendship/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { badUserInput, domainError, notFound } from '~/domain/shared/graphql/errors'

builder.mutationFields((t) => ({
  inviteFriend: t.field({
    type: FriendInvitationType,
    description:
      "The reader's invitation to share libraries, to pass on however they " +
      'like.\n\n' +
      'Asking again answers the invitation already standing rather than making ' +
      'another: a reader who taps this three times has shared one link three ' +
      'times, not left three keys to their library lying around. It stands for a ' +
      'week.',
    resolve: (_root, _args, context) => FriendshipCommand.invite(context.userId),
  }),

  acceptFriendInvitation: t.field({
    type: FriendType,
    description:
      'Take an invitation up, by its code or by the link carrying it.\n\n' +
      'Both libraries open at once: friendship here is symmetric, and there is ' +
      'nothing further to accept on the other side. The code is spent, so a ' +
      'link that reached more people than intended opens nothing twice.\n\n' +
      'Accepting an invitation already taken up answers the friendship that ' +
      'exists rather than failing. Fails with `NOT_FOUND` for a code that names ' +
      'nothing, `INVITATION_EXPIRED` past its week, and `BAD_USER_INPUT` for ' +
      "the reader's own invitation.",
    args: {
      code: t.arg.string({
        required: true,
        description: 'The code, or the invitation link that ends with it',
      }),
    },
    resolve: async (_root, args, context) => {
      const outcome = await FriendshipCommand.accept(context.userId, args.code)
      return match(outcome)
        .with('not-found', () => notFound('No invitation with that code'))
        .with('expired', () => domainError('INVITATION_EXPIRED', 'That invitation has expired'))
        .with('own-invitation', () => badUserInput('That is your own invitation'))
        .otherwise(async (friendship) => {
          const friendId = friendship.userIds.find((member) => member !== context.userId)
          const friends = await FriendshipUseCase.friends(context.userId)
          const friend = friends.find((entry) => entry.userId === friendId)
          return friend ?? notFound('Friendship not found')
        })
    },
  }),

  removeFriend: t.boolean({
    description:
      'Stop sharing libraries with somebody.\n\n' +
      'Either of the two can end it and it ends for both: one fact, and a reader ' +
      'who no longer wants to be read must not have to ask the other to agree. ' +
      'Answers false when they were not friends to begin with.',
    args: { userId: t.arg({ type: 'UserId', required: true }) },
    resolve: async (_root, args, context) =>
      (await FriendshipCommand.remove(context.userId, args.userId)) === 'removed',
  }),

  addFriendBook: t.field({
    type: BookType,
    description:
      "Put a friend's book on the reader's own shelf, on the pile or among the " +
      'books read.\n\n' +
      'Only the friend and the book are named: the server re-reads the book and ' +
      'copies its catalogue facts, never what the friend made of it — no status, ' +
      'rating, heart or note. The copy records the friend as who recommended it. ' +
      'Fails with `NOT_FOUND` for a stranger, a missing book or one marked "do ' +
      'not share", and `ALREADY_IN_LIBRARY` when the reader owns the story.',
    args: {
      userId: t.arg({ type: 'UserId', required: true, description: 'The friend' }),
      bookId: t.arg({ type: 'BookId', required: true }),
      status: t.arg({ type: CopiedStatusEnum, required: true }),
    },
    resolve: async (_root, args, context) => {
      const outcome = await FriendshipUseCase.copyBook(
        context.userId,
        args.userId,
        args.bookId,
        args.status,
      )
      return match(outcome)
        .with('not-found', () => notFound('Book not found'))
        .with('already-owned', () =>
          domainError('ALREADY_IN_LIBRARY', 'That book is already in your library'),
        )
        .otherwise(async (book) => (await BookQuery.withSignedCovers([book]))[0])
    },
  }),
}))
