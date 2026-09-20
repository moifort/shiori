import { match } from 'ts-pattern'
import { AudibleCommand } from '~/domain/audible/command'
import { AudibleMarketplaceEnum } from '~/domain/audible/infrastructure/graphql/enums'
import { audibleUnavailable, notConnected } from '~/domain/audible/infrastructure/graphql/errors'
import {
  AudibleAccountType,
  AudibleLoginType,
  AudibleSyncType,
} from '~/domain/audible/infrastructure/graphql/types'
import { AudibleQuery } from '~/domain/audible/query'
import { AudibleUseCase } from '~/domain/audible/use-case'
import { BookType } from '~/domain/book/infrastructure/graphql/types'
import { builder } from '~/domain/shared/graphql/builder'
import { badUserInput, domainError } from '~/domain/shared/graphql/errors'

builder.mutationFields((t) => ({
  startAudibleLogin: t.field({
    type: AudibleLoginType,
    description:
      'Open an Amazon sign-in for the given marketplace.\n\n' +
      'The exchange is PKCE and its secret half stays on the server: the app gets ' +
      'the page to show, the cookies to plant first and the redirect to watch ' +
      'for. Hand the authorization code that redirect carries to ' +
      '`completeAudibleLogin` within thirty minutes.\n\n' +
      'An existing connection is left working until the new sign-in completes, so ' +
      'a reader who changes their mind is not disconnected.',
    args: {
      marketplace: t.arg({
        type: AudibleMarketplaceEnum,
        required: true,
        description: 'The Amazon store the reader buys audiobooks on.',
      }),
    },
    resolve: (_root, args, context) =>
      AudibleCommand.startLogin(context.userId, args.marketplace).catch(audibleUnavailable),
  }),

  completeAudibleLogin: t.field({
    type: AudibleAccountType,
    description:
      'Register the device with the authorization code the web view caught, and ' +
      'link the account.\n\n' +
      'The credentials are sealed before they reach storage and never leave the ' +
      'server. Fails with `AUDIBLE_NO_PENDING_LOGIN` when no sign-in was started, ' +
      '`AUDIBLE_LOGIN_EXPIRED` past the thirty-minute window — start over in both ' +
      'cases — and `AUDIBLE_UNAVAILABLE` when Amazon refuses the registration.',
    args: {
      authorizationCode: t.arg.string({
        required: true,
        description: 'The `openid.oa2.authorization_code` query parameter of the landing URL.',
      }),
    },
    resolve: async (_root, args, context) => {
      const code = args.authorizationCode.trim()
      if (!code) return badUserInput('The authorization code is empty')
      const result = await AudibleCommand.completeLogin(context.userId, code).catch(
        audibleUnavailable,
      )
      return match(result)
        .with('no-pending-login', () =>
          domainError('AUDIBLE_NO_PENDING_LOGIN', 'No Audible sign-in is in progress'),
        )
        .with('login-expired', () =>
          domainError('AUDIBLE_LOGIN_EXPIRED', 'The Audible sign-in expired; start it again'),
        )
        .otherwise((account) => account)
    },
  }),

  importAudibleBooks: t.field({
    type: [BookType],
    description:
      'Catalogue the Audible titles the reader ticked, and return the books ' +
      'created.\n\n' +
      'The library is read again from Amazon rather than trusted from the app: ' +
      'the client sends identifiers, every stored field comes from the source. An ' +
      'ASIN the library does not hold matches nothing, and a title already ' +
      'catalogued is skipped — so calling this twice with the same list creates ' +
      'no duplicates.\n\n' +
      'Consumes no scan credit: an import calls no model. Fails with ' +
      '`AUDIBLE_NOT_CONNECTED` and `AUDIBLE_UNAVAILABLE` like `audibleLibrary`.',
    args: {
      asins: t.arg({
        type: ['AudibleAsin'],
        required: true,
        description: 'The ASINs to catalogue, from `audibleLibrary`.',
      }),
    },
    resolve: async (_root, args, context) => {
      const result = await AudibleUseCase.importBooks(context.userId, args.asins).catch(
        audibleUnavailable,
      )
      const books = match(result)
        .with('not-connected', notConnected)
        .otherwise((imported) => imported)
      // `addBook` reads its book back to have the cover URL attached; an import
      // does not, because it knows the answer. An imported book has no photo of
      // its own — there was no camera involved — so the only cover it can draw is
      // the one Audible supplied, and re-reading a whole library to learn that
      // would cost one document read per title.
      return books.map((book) => ({ ...book, coverUrl: book.publishedCoverUrl }))
    },
  }),

  setAudibleAutoSync: t.field({
    type: AudibleAccountType,
    description:
      'Turn the nightly Audible sync on or off.\n\n' +
      'On, a nightly pass catalogues what the reader bought since the last one ' +
      'and moves imported books to the status Audible reports — a title finished ' +
      'there becomes `READ` here, one it says was never opened goes back to the ' +
      'pile. Off, nothing happens until the reader imports by hand again; books ' +
      'already catalogued stay exactly as they are.\n\n' +
      'Fails with `AUDIBLE_NOT_CONNECTED` when no account is linked: there is no ' +
      'library to sync, so there is no setting to keep.',
    args: {
      enabled: t.arg.boolean({ required: true }),
    },
    resolve: async (_root, args, context) => {
      const result = await AudibleCommand.setAutoSync(context.userId, args.enabled)
      return match(result)
        .with('not-connected', notConnected)
        .otherwise((account) => account)
    },
  }),

  syncAudibleNow: t.field({
    type: AudibleSyncType,
    description:
      'Run a pass over the Audible library right now, without waiting for the ' +
      'night.\n\n' +
      'The same pass the nightly job runs: titles bought since the last one are ' +
      'catalogued, and books already catalogued follow the listening — finished on ' +
      'Audible becomes `READ` here, with the date Audible reports rather than ' +
      "today's. Ratings, notes and hidden books are never touched.\n\n" +
      'Runs whether or not the nightly sync is on. `setAudibleAutoSync` governs ' +
      'what happens unasked; this is the reader asking.\n\n' +
      'Consumes no scan credit. Fails with `AUDIBLE_NOT_CONNECTED` and ' +
      '`AUDIBLE_UNAVAILABLE` like `audibleLibrary`.',
    resolve: async (_root, _args, context) => {
      const sync = await AudibleUseCase.syncLibrary(context.userId, new Date(), true).catch(
        audibleUnavailable,
      )
      return (
        match(sync)
          .with('not-connected', notConnected)
          // Unreachable: an on-demand pass walks past the switch by construction.
          .with('sync-disabled', () => {
            throw new Error('an on-demand Audible sync cannot be refused by the nightly switch')
          })
          .otherwise(async (changed) => {
            const account = await AudibleQuery.accountOf(context.userId)
            if (!account) return notConnected()
            return { sync: changed, account }
          })
      )
    },
  }),

  disconnectAudible: t.boolean({
    description:
      'Forget the Audible connection. Books already imported stay in the library.' +
      '\n\n' +
      'Only our copy of the credentials goes: the device stays registered on the ' +
      'Amazon side until the reader removes it from their account there. Returns ' +
      'false when there was nothing to disconnect.',
    resolve: async (_root, _args, context) =>
      (await AudibleCommand.disconnect(context.userId)) === 'disconnected',
  }),
}))
