import { match } from 'ts-pattern'
import { kindleUnavailable, notConnected } from '~/domain/kindle/infrastructure/graphql/errors'
import {
  ImportableKindleBookType,
  KindleAccountType,
} from '~/domain/kindle/infrastructure/graphql/types'
import { KindleQuery } from '~/domain/kindle/query'
import { KindleUseCase } from '~/domain/kindle/use-case'
import { builder } from '~/domain/shared/graphql/builder'

builder.queryFields((t) => ({
  kindleAccount: t.field({
    type: KindleAccountType,
    nullable: true,
    description:
      "The reader's Kindle connection, or null when there is none.\n\n" +
      'A sign-in left half-finished reads as null: the screen must offer to ' +
      'connect, not claim a library no credentials back.',
    resolve: async (_root, _args, context) => (await KindleQuery.accountOf(context.userId)) ?? null,
  }),

  kindleLibrary: t.field({
    type: [ImportableKindleBookType],
    description:
      'The whole Kindle library, as books the reader could catalogue.\n\n' +
      'Nothing is saved and no AI runs, so this costs no scan credit. Every title ' +
      'is returned, including those already catalogued — they come back with ' +
      '`alreadyInLibrary` set so the picker can show them rather than hide them.\n\n' +
      'Fails with `KINDLE_NOT_CONNECTED` when no library is linked, and ' +
      '`KINDLE_UNAVAILABLE` when Amazon refuses the call — a deregistered device ' +
      'or a changed password lands here, and the fix is to connect again.',
    resolve: async (_root, _args, context) => {
      const result = await KindleUseCase.importableBooks(context.userId).catch(kindleUnavailable)
      return match(result)
        .with('not-connected', notConnected)
        .otherwise((books) => books)
    },
  }),
}))
