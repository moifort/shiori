import { match } from 'ts-pattern'
import { ReadingStatusEnum } from '~/domain/book/infrastructure/graphql/enums'
import { KindleMarketplaceEnum } from '~/domain/kindle/infrastructure/graphql/enums'
import { kindleUnavailable, notConnected } from '~/domain/kindle/infrastructure/graphql/errors'
import type {
  ConnectedKindleAccount,
  ExportedKindleBook,
  ImportableKindleBook,
  KindleLibrarySync,
  KindleLogin,
} from '~/domain/kindle/types'
import { KindleUseCase } from '~/domain/kindle/use-case'
import { builder } from '~/domain/shared/graphql/builder'

const KindleCookieType = builder
  .objectRef<KindleLogin['cookies'][number]>('KindleCookie')
  .implement({
    description:
      'A cookie to plant in the web view before loading the sign-in page. They are ' +
      'what makes the request look like the Kindle iOS app, and without them Amazon ' +
      'challenges the sign-in far more often.',
    fields: (t) => ({
      name: t.exposeString('name'),
      value: t.exposeString('value'),
      domain: t.exposeString('domain'),
    }),
  })

export const KindleLoginType = builder.objectRef<KindleLogin>('KindleLogin').implement({
  description:
    'Everything needed to run the Amazon sign-in for a Kindle library in a web view.\n\n' +
    'Plant the cookies, load `url`, and watch navigation for `redirectUrl`: it ' +
    'carries the authorization code as the `openid.oa2.authorization_code` query ' +
    'parameter. Hand that code to `completeKindleLogin` within thirty minutes.',
  fields: (t) => ({
    url: t.exposeString('url', { description: 'The Amazon sign-in page to load.' }),
    cookies: t.field({ type: [KindleCookieType], resolve: (login) => login.cookies }),
    redirectUrl: t.exposeString('redirectUrl', {
      description: 'The landing URL whose query string carries the authorization code.',
    }),
  }),
})

export const ImportableKindleBookType = builder
  .objectRef<ImportableKindleBook>('ImportableKindleBook')
  .implement({
    description:
      'One Kindle book of the connected library, as it would be catalogued.\n\n' +
      'A proposal, not a record — the contract `scanBook` has. Nothing is saved ' +
      'until `importKindleLibrary` is called with the ASINs the reader ticked. ' +
      'Every imported book is catalogued as an `EBOOK`. Samples and the ' +
      'dictionaries Amazon files under every account are never listed.',
    fields: (t) => ({
      asin: t.field({
        type: 'KindleAsin',
        description: 'Pass this back to `importKindleLibrary` to catalogue the title.',
        resolve: (importable) => importable.asin,
      }),
      title: t.field({
        type: 'BookTitle',
        description:
          "The volume's own title, the saga taken out of it: Amazon titles a volume " +
          '"Powerless (Tome 3) - Fearless", the book is "Fearless".',
        resolve: (importable) => importable.title,
      }),
      authors: t.field({ type: ['AuthorName'], resolve: (importable) => importable.authors }),
      coverUrl: t.field({
        type: 'CoverUrl',
        nullable: true,
        resolve: (importable) => importable.coverUrl ?? null,
      }),
      seriesName: t.field({
        type: 'SeriesName',
        nullable: true,
        description:
          'Read off the title, which is where Amazon puts the saga. Null for a ' +
          'standalone title and for one whose title names its saga in no shape ' +
          'the server recognizes — a guessed saga would be worse than none.',
        resolve: (importable) => importable.series?.name ?? null,
      }),
      volume: t.field({
        type: 'VolumeNumber',
        nullable: true,
        resolve: (importable) => importable.series?.volume ?? null,
      }),
      status: t.field({
        type: ReadingStatusEnum,
        description:
          'Where Amazon says the reader stands: `READ` when Kindle marked it read — ' +
          'on reaching the end, or by hand — and the pile otherwise. Amazon never ' +
          'says a book is being read.',
        resolve: (importable) => importable.status,
      }),
      alreadyInLibrary: t.boolean({
        description:
          'True when a book with the same title and author is already catalogued, ' +
          'whatever its edition. Leave these unticked: `importKindleLibrary` skips ' +
          'them anyway.',
        resolve: (importable) => importable.alreadyInLibrary,
      }),
    }),
  })

const libraryOf = async (userId: Parameters<typeof KindleUseCase.importableBooks>[0]) => {
  const result = await KindleUseCase.importableBooks(userId).catch(kindleUnavailable)
  return match(result)
    .with('not-connected', notConnected)
    .otherwise((books) => books)
}

export const KindleAccountType = builder
  .objectRef<ConnectedKindleAccount>('KindleAccount')
  .implement({
    description:
      "The reader's live link to their Kindle library.\n\n" +
      'Independent of the Audible connection: its own device, its own credentials, ' +
      'its own nightly pass. The credentials never leave the server; disconnecting ' +
      'forgets our copy, and the device stays registered on the Amazon side until ' +
      'the reader removes it there.',
    fields: (t) => ({
      marketplace: t.field({
        type: KindleMarketplaceEnum,
        resolve: (account) => account.marketplace,
      }),
      connectedAt: t.field({ type: 'DateTime', resolve: (account) => account.connectedAt }),
      lastImportedAt: t.field({
        type: 'DateTime',
        nullable: true,
        description: 'Null until the first import or pass, then moved by every one.',
        resolve: (account) => account.lastImportedAt ?? null,
      }),
      autoSync: t.boolean({
        description:
          'Whether the nightly sync runs for this reader.\n\n' +
          'When on, a pass each night catalogues the titles acquired since the last ' +
          'one and moves to `READ` the books Kindle newly marks read — never the ' +
          'other way. Ratings, notes and hidden books are never touched.',
        resolve: (account) => account.autoSync !== false,
      }),
      lastSyncFailedAt: t.field({
        type: 'DateTime',
        nullable: true,
        description:
          'When the nightly pass last failed, null once one works again. Amazon ' +
          'refusing the device is the usual reason, and connecting again the fix.',
        resolve: (account) => account.lastSyncFailedAt ?? null,
      }),
      library: t.field({
        type: [ImportableKindleBookType],
        description:
          'The whole Kindle library, as `kindleLibrary` answers it, read in the same ' +
          'request as the connection. Fails with `KINDLE_UNAVAILABLE` when Amazon ' +
          'refuses the call.',
        resolve: (_account, _args, context) => libraryOf(context.userId),
      }),
    }),
  })

/** What a pass over the library did, and the account as it stands after it, so
 *  the screen that asked redraws itself whole in one round trip. `linked` is
 *  not here: it happens once, and means nothing to a reader. */
export const KindleSyncType = builder
  .objectRef<{ sync: KindleLibrarySync; account: ConnectedKindleAccount }>('KindleSync')
  .implement({
    description: 'What one pass over the Kindle library changed.',
    fields: (t) => ({
      imported: t.int({
        description: 'Titles acquired since the last pass, now catalogued.',
        resolve: ({ sync }) => sync.imported,
      }),
      updated: t.int({
        description: 'Books Kindle newly marks read, moved to `READ`.',
        resolve: ({ sync }) => sync.moved,
      }),
      account: t.field({
        type: KindleAccountType,
        description: 'The connection after the pass, its `lastImportedAt` moved.',
        resolve: ({ account }) => account,
      }),
    }),
  })

export const KindleBookType = builder.objectRef<ExportedKindleBook>('KindleBook').implement({
  description:
    'One title read off an Amazon data export, before anything is saved.\n\n' +
    'Thin on purpose: the export is a purchase history, not a catalogue. It ' +
    'names the book and who wrote it and carries nothing else — no summary, ' +
    'no cover, no series — so a book catalogued from it is a stub the reader ' +
    'can scan or correct afterwards.',
  fields: (t) => ({
    key: t.exposeString('key', {
      description:
        'What to tick: the title and first author folded together, the way the ' +
        'duplicate check folds them. Pass the ones wanted to `importKindleBooks`.',
    }),
    title: t.field({ type: 'BookTitle', resolve: (book) => book.title }),
    authors: t.field({ type: ['AuthorName'], resolve: (book) => book.authors }),
    alreadyInLibrary: t.exposeBoolean('alreadyInLibrary', {
      description:
        'Already on the shelf under this title and author, whatever the edition. ' +
        'Show it ticked off and untappable rather than hiding it: hidden, it ' +
        'reads as a title the import lost.',
    }),
  }),
})
