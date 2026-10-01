import { match } from 'ts-pattern'
import { BookType } from '~/domain/book/infrastructure/graphql/types'
import { KindleCommand } from '~/domain/kindle/command'
import { KindleMarketplaceEnum } from '~/domain/kindle/infrastructure/graphql/enums'
import { kindleUnavailable, notConnected } from '~/domain/kindle/infrastructure/graphql/errors'
import {
  KindleAccountType,
  KindleBookType,
  KindleLoginType,
  KindleSyncType,
} from '~/domain/kindle/infrastructure/graphql/types'
import { KindleQuery } from '~/domain/kindle/query'
import { KindleUseCase } from '~/domain/kindle/use-case'
import { builder } from '~/domain/shared/graphql/builder'
import { badUserInput, domainError } from '~/domain/shared/graphql/errors'

/** Amazon's export of a big library runs to a few hundred rows of title and
 *  author. A megabyte is far past that and stops a paste of something else
 *  entirely from being parsed as a spreadsheet. */
const MAX_EXPORT_BYTES = 1_000_000

const UNREADABLE =
  'This file carries no column that could hold a title. Amazon ships several ' +
  'CSVs in one archive: the one to send is the list of digital content owned, ' +
  'not an order history or a reading session.'

builder.mutationFields((t) => ({
  startKindleLogin: t.field({
    type: KindleLoginType,
    description:
      'Open an Amazon sign-in for a Kindle library on the given store.\n\n' +
      'The exchange is PKCE and its secret half stays on the server: the app gets ' +
      'the page to show, the cookies to plant first and the redirect to watch for. ' +
      'Hand the authorization code that redirect carries to `completeKindleLogin` ' +
      'within thirty minutes. An existing connection keeps working until the new ' +
      'sign-in completes.',
    args: {
      marketplace: t.arg({
        type: KindleMarketplaceEnum,
        required: true,
        description: 'The Amazon store the reader buys Kindle books on.',
      }),
    },
    resolve: async (_root, args, context) =>
      KindleCommand.startLogin(context.userId, args.marketplace).catch(kindleUnavailable),
  }),

  completeKindleLogin: t.field({
    type: KindleAccountType,
    description:
      'Register a Kindle device with the authorization code the web view caught, ' +
      'and link the library.\n\n' +
      'The credentials are sealed before they reach storage and never leave the ' +
      'server. Fails with `KINDLE_NO_PENDING_LOGIN` when no sign-in was started, ' +
      '`KINDLE_LOGIN_EXPIRED` past the thirty-minute window — start over in both ' +
      'cases — and `KINDLE_UNAVAILABLE` when Amazon refuses the registration.',
    args: {
      authorizationCode: t.arg.string({
        required: true,
        description: 'The `openid.oa2.authorization_code` query parameter of the landing URL.',
      }),
    },
    resolve: async (_root, args, context) => {
      const code = args.authorizationCode.trim()
      if (!code) return badUserInput('The authorization code is empty')
      const result = await KindleCommand.completeLogin(context.userId, code).catch(
        kindleUnavailable,
      )
      return match(result)
        .with('no-pending-login', () =>
          domainError('KINDLE_NO_PENDING_LOGIN', 'No Kindle sign-in is in progress'),
        )
        .with('login-expired', () =>
          domainError('KINDLE_LOGIN_EXPIRED', 'The Kindle sign-in expired; start it again'),
        )
        .otherwise((account) => account)
    },
  }),

  importKindleLibrary: t.field({
    type: [BookType],
    description:
      'Catalogue the Kindle titles the reader ticked, and return the books created.' +
      '\n\n' +
      'The library is read again from Amazon rather than trusted from the app: the ' +
      'client sends identifiers, every stored field comes from the source. An ASIN ' +
      'the library does not hold matches nothing, and a title already catalogued is ' +
      'skipped — so calling this twice with the same list creates no duplicates.\n\n' +
      'Each book is an `EBOOK` with its cover, its saga when the title names one, and ' +
      '`READ` when Kindle marked it read. Consumes no scan credit. Fails with ' +
      '`KINDLE_NOT_CONNECTED` and `KINDLE_UNAVAILABLE` like `kindleLibrary`.',
    args: {
      asins: t.arg({
        type: ['KindleAsin'],
        required: true,
        description: 'The ASINs to catalogue, from `kindleLibrary`.',
      }),
    },
    resolve: async (_root, args, context) => {
      const result = await KindleUseCase.importBooks(context.userId, args.asins).catch(
        kindleUnavailable,
      )
      const books = match(result)
        .with('not-connected', notConnected)
        .otherwise((imported) => imported)
      // An imported book has no photo of its own: the only cover it can draw is
      // the one Amazon supplied, so it is not read back to learn that.
      return books.map((book) => ({ ...book, coverUrl: book.publishedCoverUrl }))
    },
  }),

  setKindleAutoSync: t.field({
    type: KindleAccountType,
    description:
      'Turn the nightly Kindle sync on or off.\n\n' +
      'On, a nightly pass catalogues what the reader acquired since the last one ' +
      'and moves to `READ` the books Kindle newly marks read. Off, nothing happens ' +
      'until the reader imports by hand again. Fails with `KINDLE_NOT_CONNECTED` ' +
      'when no library is linked.',
    args: {
      enabled: t.arg.boolean({ required: true }),
    },
    resolve: async (_root, args, context) => {
      const result = await KindleCommand.setAutoSync(context.userId, args.enabled)
      return match(result)
        .with('not-connected', notConnected)
        .otherwise((account) => account)
    },
  }),

  syncKindleNow: t.field({
    type: KindleSyncType,
    description:
      'Run a pass over the Kindle library right now, without waiting for the night.' +
      '\n\n' +
      'The same pass the nightly job runs: titles acquired since the last one are ' +
      'catalogued, and books Kindle newly marks read move to `READ`. Nothing ever ' +
      'moves the other way, and ratings, notes and hidden books are never touched. ' +
      'Runs whether or not the nightly sync is on.\n\n' +
      'Consumes no scan credit. Fails with `KINDLE_NOT_CONNECTED` and ' +
      '`KINDLE_UNAVAILABLE` like `kindleLibrary`.',
    resolve: async (_root, _args, context) => {
      const sync = await KindleUseCase.syncLibrary(context.userId, new Date(), true).catch(
        kindleUnavailable,
      )
      return (
        match(sync)
          .with('not-connected', notConnected)
          // Unreachable: an on-demand pass walks past the switch by construction.
          .with('sync-disabled', () => {
            throw new Error('an on-demand Kindle sync cannot be refused by the nightly switch')
          })
          .otherwise(async (changed) => {
            const account = await KindleQuery.accountOf(context.userId)
            if (!account) return notConnected()
            return { sync: changed, account }
          })
      )
    },
  }),

  disconnectKindle: t.boolean({
    description:
      'Forget the Kindle connection. Books already imported stay in the library.\n\n' +
      'Only our copy of the credentials goes: the device stays registered on the ' +
      'Amazon side until the reader removes it from their account there. Returns ' +
      'false when there was nothing to disconnect.',
    resolve: async (_root, _args, context) =>
      (await KindleCommand.disconnect(context.userId)) === 'disconnected',
  }),

  readKindleExport: t.field({
    type: [KindleBookType],
    deprecationReason:
      'Connect the Kindle library instead: `startKindleLogin`, then `kindleLibrary`.',
    description:
      'Read an Amazon data export and answer with the books it holds, ticked ' +
      'against the library they would join.\n\n' +
      'Nothing is saved: the answer is a proposal, as a scan is. The app lists ' +
      'the titles, the reader ticks, and `importKindleBooks` catalogues those.\n\n' +
      'No model is called and no scan is spent — this reads a file. Fails with ' +
      '`BAD_USER_INPUT` for a file above one megabyte or one with no title ' +
      'column, which is what the wrong CSV out of the archive looks like.',
    args: {
      csv: t.arg.string({ required: true, description: 'The export file, as text' }),
    },
    resolve: async (_root, { csv }, { userId }) => {
      if (csv.length > MAX_EXPORT_BYTES) return badUserInput('Export exceeds the 1 MB limit')
      const found = await KindleUseCase.readExport(userId, csv)
      return found === 'no-title-column' ? badUserInput(UNREADABLE) : found
    },
  }),

  importKindleBooks: t.field({
    type: [BookType],
    deprecationReason: 'Use `importKindleLibrary`, which reads a connected Kindle library.',
    description:
      'Catalogue the titles the reader ticked, from the keys `readKindleExport` ' +
      'answered with.\n\n' +
      'The file is sent again rather than the records: it is read a second time ' +
      'and the keys only say which of its rows were wanted, so every stored ' +
      'field comes from the export. A title already on the shelf is skipped ' +
      'however it was ticked.\n\n' +
      'Each book lands on the pile as an ebook with its title and author and ' +
      'nothing else: that is all the export carries. Answers the books actually ' +
      'catalogued, which is empty when every ticked title was already owned.',
    args: {
      csv: t.arg.string({ required: true, description: 'The same export file, as text' }),
      keys: t.arg.stringList({ required: true, description: 'The keys of the ticked books' }),
    },
    resolve: async (_root, { csv, keys }, { userId }) => {
      if (csv.length > MAX_EXPORT_BYTES) return badUserInput('Export exceeds the 1 MB limit')
      const imported = await KindleUseCase.importExport(userId, csv, keys)
      return imported === 'no-title-column' ? badUserInput(UNREADABLE) : imported
    },
  }),
}))
