import { match } from 'ts-pattern'
import { audibleUnavailable, notConnected } from '~/domain/audible/infrastructure/graphql/errors'
import {
  AudibleAccountType,
  ImportableBookType,
} from '~/domain/audible/infrastructure/graphql/types'
import { AudibleQuery } from '~/domain/audible/query'
import { AudibleUseCase } from '~/domain/audible/use-case'
import { builder } from '~/domain/shared/graphql/builder'

builder.queryFields((t) => ({
  audibleAccount: t.field({
    type: AudibleAccountType,
    nullable: true,
    description:
      "The reader's Audible connection, or null when there is none.\n\n" +
      'A sign-in left half-finished reads as null: the settings screen must offer ' +
      'to connect, not claim an account no credentials back.',
    resolve: async (_root, _args, context) =>
      (await AudibleQuery.accountOf(context.userId)) ?? null,
  }),

  audibleLibrary: t.field({
    type: [ImportableBookType],
    description:
      'The whole Audible library, as books the reader could catalogue.\n\n' +
      'Nothing is saved and no AI runs, so this costs no scan credit. Every title ' +
      'is returned, including those already catalogued — they come back with ' +
      '`alreadyInLibrary` set so the picker can leave them unticked rather than ' +
      'hide them.\n\n' +
      'Fails with `AUDIBLE_NOT_CONNECTED` when no account is linked, and ' +
      '`AUDIBLE_UNAVAILABLE` when Amazon refuses the call — a revoked device or a ' +
      'changed password lands here, and the fix is to connect again.',
    resolve: async (_root, _args, context) => {
      const result = await AudibleUseCase.importableBooks(context.userId).catch(audibleUnavailable)
      return match(result)
        .with('not-connected', notConnected)
        .otherwise((books) => books)
    },
  }),
}))
