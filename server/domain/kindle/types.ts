import type { Brand } from 'ts-brand'
import type { BookLanguage, CoverUrl, ReadingStatus, SeriesMembership } from '~/domain/book/types'
import type { AuthorName, BookTitle, UserId } from '~/domain/shared/types'

/** Amazon's product identifier for a Kindle edition. Ten alphanumeric
 *  characters, `B0G26NZ911`. */
export type KindleAsin = Brand<string, 'KindleAsin'>

/** The Amazon store a Kindle library lives on. It decides which domain the
 *  sign-in page and the content list live on, so a connection made on the wrong
 *  one simply finds an empty library. */
export const KINDLE_MARKETPLACES = [
  'fr',
  'com',
  'co.uk',
  'de',
  'it',
  'es',
  'ca',
  'com.au',
  'in',
  'co.jp',
] as const
export type KindleMarketplace = (typeof KINDLE_MARKETPLACES)[number]

/** The device credentials, encrypted. What they hold is a standing grant on
 *  somebody's Amazon account, so a database export must not be enough to use
 *  it. */
export type SealedKindleCredentials = Brand<string, 'SealedKindleCredentials'>

/** A reader's link to their Kindle library, one document per reader.
 *
 *  Both halves are optional because the document outlives either: a sign-in in
 *  flight has a `pending` and no account yet, a connected reader has an account
 *  and no `pending`, and a reader reconnecting briefly has both. */
export type KindleConnection = {
  userId: UserId
  account?: ConnectedKindleAccount
  pending?: PendingKindleLogin
}

/** A live link to a Kindle library: credentials that worked, and when. */
export type ConnectedKindleAccount = {
  marketplace: KindleMarketplace
  credentials: SealedKindleCredentials
  connectedAt: Date
  /** The last pass over the library, by hand or by night. It doubles as the
   *  cutoff the sync catalogues from: a title acquired before it was on offer
   *  when the reader last chose, and their choice stands. */
  lastImportedAt?: Date
  /** Whether the nightly sync runs for this reader. Absent reads as enabled. */
  autoSync?: boolean
  /** The titles Amazon reported read at the last pass.
   *
   *  `READ` never goes away on Amazon's side, so it is news only once: kept here,
   *  a title already in the set moves nothing, and a reader who starts a book
   *  again is not put back on "read" every night. Absent until the first pass. */
  readAsins?: KindleAsin[]
  /** When a nightly pass last failed, cleared by the next one that works. What
   *  the app reads to offer a reconnection rather than a library gone quiet. */
  lastSyncFailedAt?: Date
}

/** A half-finished sign-in. PKCE hands the code verifier out before the
 *  authorization code comes back; kept here so the app never holds a piece of
 *  the exchange, and dropped the moment the device is registered. */
export type PendingKindleLogin = {
  marketplace: KindleMarketplace
  codeVerifier: string
  serial: string
  startedAt: Date
}

/** Everything the app needs to drive the Amazon sign-in in a web view. */
export type KindleLogin = {
  url: string
  cookies: { name: string; value: string; domain: string }[]
  redirectUrl: string
}

/** One Kindle book of the reader's library, as it would be catalogued.
 *
 *  A proposal, not a record: the app lists these, the reader ticks, and only
 *  then are books written. */
export type ImportableKindleBook = {
  asin: KindleAsin
  title: BookTitle
  authors: AuthorName[]
  coverUrl?: CoverUrl
  /** Read off the title, which is where Amazon puts the saga. Absent when no
   *  pattern recognizes one, rather than guessed. */
  series?: SeriesMembership
  /** The language of the edition, which Amazon names in the title or its sort
   *  key. Absent when neither does. */
  language?: BookLanguage
  status: ReadingStatus
  /** Amazon says a book was read, never when. A book imported as read is dated
   *  finished on the day it was acquired — the honest lower bound — so a decade
   *  of reading does not land on import night. */
  finishedAt?: Date
  /** When the title entered the account, kept as the book's own addition date. */
  addedAt?: Date
  alreadyInLibrary: boolean
}

/** What one pass over a reader's library changed. Counts rather than records:
 *  naming the books would put a reader's library into an operations log. */
export type KindleLibrarySync = {
  /** Ebooks catalogued before the link, matched by shelf key and linked. */
  linked: number
  /** Books moved to read because Amazon newly says so. */
  moved: number
  /** Titles acquired since the last pass, catalogued. */
  imported: number
}

/** What one run of the nightly job did, across every reader it reached. */
export type KindleSyncRun = {
  synced: number
  failed: number
  deferred: number
}

/** One title read off an Amazon data export, ready to be ticked.
 *
 *  Far thinner than a connected import, and honestly so: the export is a list of
 *  purchases, not a catalogue. Kept for the deprecated export import only. */
export type ExportedKindleBook = {
  /** The title and first author folded together, as the duplicate check folds
   *  them. What the app ticks, so two books sharing a title are two rows. */
  key: string
  title: BookTitle
  authors: AuthorName[]
  alreadyInLibrary: boolean
}

/** What a file that is not an Amazon export answers with. */
export type UnreadableExport = 'no-title-column'
