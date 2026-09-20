import { AudibleMarketplaceEnum } from '~/domain/audible/infrastructure/graphql/enums'
import type { AudibleLogin, ConnectedAccount, ImportableBook } from '~/domain/audible/types'
import { ReadingStatusEnum } from '~/domain/book/infrastructure/graphql/enums'
import { builder } from '~/domain/shared/graphql/builder'

const AudibleCookieType = builder
  .objectRef<AudibleLogin['cookies'][number]>('AudibleCookie')
  .implement({
    description:
      'A cookie to plant in the web view before loading the sign-in page.\n\n' +
      'They are what makes the request look like the Audible iOS app. Without ' +
      'them Amazon challenges the sign-in far more often, so they are not ' +
      'optional garnish.',
    fields: (t) => ({
      name: t.exposeString('name'),
      value: t.exposeString('value'),
      domain: t.exposeString('domain'),
    }),
  })

export const AudibleLoginType = builder.objectRef<AudibleLogin>('AudibleLogin').implement({
  description:
    'Everything needed to run the Amazon sign-in in a web view.\n\n' +
    'Plant the cookies, load `url`, and watch navigation for `redirectUrl`: it ' +
    'carries the authorization code as the `openid.oa2.authorization_code` query ' +
    'parameter. Hand that code to `completeAudibleLogin` and close the view. The ' +
    'sign-in is good for thirty minutes.',
  fields: (t) => ({
    url: t.exposeString('url', { description: 'The Amazon sign-in page to load.' }),
    cookies: t.field({ type: [AudibleCookieType], resolve: (login) => login.cookies }),
    redirectUrl: t.exposeString('redirectUrl', {
      description: 'The landing URL whose query string carries the authorization code.',
    }),
  }),
})

export const AudibleAccountType = builder.objectRef<ConnectedAccount>('AudibleAccount').implement({
  description:
    "The reader's live link to Audible.\n\n" +
    'The credentials themselves never leave the server. Disconnecting forgets ' +
    'our copy of them; the device stays registered on the Amazon side until the ' +
    'reader removes it there.',
  fields: (t) => ({
    marketplace: t.field({
      type: AudibleMarketplaceEnum,
      resolve: (account) => account.marketplace,
    }),
    connectedAt: t.field({ type: 'DateTime', resolve: (account) => account.connectedAt }),
    lastImportedAt: t.field({
      type: 'DateTime',
      nullable: true,
      description: 'Null until the first import.',
      resolve: (account) => account.lastImportedAt ?? null,
    }),
  }),
})

export const ImportableBookType = builder.objectRef<ImportableBook>('ImportableBook').implement({
  description:
    'One audiobook of the Audible library, as it would be catalogued.\n\n' +
    'A proposal, not a record — the same contract `scanBook` has. Nothing is ' +
    'saved until `importAudibleBooks` is called with the ASINs the reader ' +
    'ticked. Every imported book is catalogued as an `AUDIOBOOK`.',
  fields: (t) => ({
    asin: t.field({
      type: 'AudibleAsin',
      description: 'Pass this back to `importAudibleBooks` to catalogue the title.',
      resolve: (importable) => importable.asin,
    }),
    title: t.field({ type: 'BookTitle', resolve: (importable) => importable.title }),
    authors: t.field({ type: ['AuthorName'], resolve: (importable) => importable.authors }),
    narrators: t.field({
      type: ['NarratorName'],
      description:
        'Who reads it. Shown in the picker to tell two recordings apart, and ' +
        'kept on the book: Audible is the only source that names them.',
      resolve: (importable) => importable.narrators,
    }),
    durationMinutes: t.int({
      nullable: true,
      description:
        "Audible's running time, kept on the book: it is what the listening " +
        'statistics count, the way pages are what the reading statistics count.',
      resolve: (importable) => importable.durationMinutes ?? null,
    }),
    coverUrl: t.field({
      type: 'CoverUrl',
      nullable: true,
      resolve: (importable) => importable.coverUrl ?? null,
    }),
    seriesName: t.field({
      type: 'SeriesName',
      nullable: true,
      description: 'Null for a standalone title.',
      resolve: (importable) => importable.series?.name ?? null,
    }),
    volume: t.field({
      type: 'VolumeNumber',
      nullable: true,
      description: 'Null outside a numbered spine — Audible numbers side stories 4.5.',
      resolve: (importable) => importable.series?.volume ?? null,
    }),
    status: t.field({
      type: ReadingStatusEnum,
      description:
        'Where Audible says the reader stands: finished is `READ`, started is ' +
        '`READING`, an untouched purchase lands on the pile.',
      resolve: (importable) => importable.status,
    }),
    finishedAt: t.field({
      type: 'DateTime',
      nullable: true,
      description:
        'When the listening ended, kept on the imported book so a decade of ' +
        'listening does not land on today and rewrite the reading statistics.',
      resolve: (importable) => importable.finishedAt ?? null,
    }),
    alreadyInLibrary: t.boolean({
      description:
        'True when a book with the same title and author is already catalogued — ' +
        'whether it was imported before or scanned from the printed edition. ' +
        'Leave these unticked: `importAudibleBooks` skips them anyway.',
      resolve: (importable) => importable.alreadyInLibrary,
    }),
  }),
})
