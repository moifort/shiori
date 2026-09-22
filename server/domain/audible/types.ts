import type { Brand } from 'ts-brand'
import type {
  BookLanguage,
  CoverUrl,
  Genre,
  Isbn13,
  ListeningMinutes,
  LocalizedSubgenre,
  NarratorName,
  Publisher,
  ReadingStatus,
  SeriesMembership,
  Synopsis,
} from '~/domain/book/types'
import type { AuthorName, BookTitle, UserId } from '~/domain/shared/types'

/** Amazon's product identifier, the stable handle on an audiobook. Ten
 *  alphanumeric characters, `B002V1OF70`. */
export type AudibleAsin = Brand<string, 'AudibleAsin'>

/** The Amazon marketplace an account was opened on. It decides which domain the
 *  sign-in page and the API live on, so a connection is worthless without it. */
export const AUDIBLE_MARKETPLACES = [
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
export type AudibleMarketplace = (typeof AUDIBLE_MARKETPLACES)[number]

/** The device credentials, encrypted. Never a plain object in storage: what they
 *  hold is a standing grant on somebody's Amazon account, and a database export
 *  must not be enough to use it. */
export type SealedCredentials = Brand<string, 'SealedCredentials'>

/** A reader's link to their Audible account, one document per reader.
 *
 *  Both halves are optional because the document outlives either of them: a
 *  sign-in in flight has a `pending` and no account yet, a connected reader has
 *  an account and no `pending`, and a reader reconnecting on another marketplace
 *  briefly has both — which is why the marketplace is recorded on each rather
 *  than once on the document. */
export type AudibleConnection = {
  userId: UserId
  account?: ConnectedAccount
  pending?: PendingLogin
}

/** A live link to Audible: credentials that worked, and when. */
export type ConnectedAccount = {
  marketplace: AudibleMarketplace
  credentials: SealedCredentials
  connectedAt: Date
  /** The last time Amazon was read for this reader, by hand or by the nightly
   *  sync. It doubles as the cutoff the sync buys from: a title whose purchase
   *  predates it was on offer when the reader last chose, and their choice not to
   *  catalogue it stands. */
  lastImportedAt?: Date
  /** Whether the nightly sync runs for this reader. Absent reads as enabled —
   *  connections made before the setting existed are the ones it was built for,
   *  and a reader who links their account wants it to follow them. */
  autoSync?: boolean
}

/** What one night's pass over a reader's library changed.
 *
 *  Counts rather than records: nothing reads this but a log line and the admin
 *  endpoint's answer, and naming the books would put a reader's library into an
 *  operations log. */
export type LibrarySync = {
  /** Books imported before the ASIN was kept, matched to their Audible title by
   *  shelf key and linked for good. Only ever non-zero on the first pass. */
  linked: number
  /** Statuses moved to follow the listening. */
  moved: number
  /** Titles bought since the last pass, catalogued. */
  imported: number
}

/** What one run of the nightly job did, across every reader it reached. */
export type SyncRun = {
  synced: number
  /** Readers whose pass threw — one bad Amazon call must not cost the others
   *  their night. */
  failed: number
  /** Readers left for the next run because the time budget ran out. */
  deferred: number
}

/** A half-finished sign-in. PKCE hands the code verifier out before the
 *  authorization code comes back, and the two have to meet again to register the
 *  device. Kept here rather than sent to the app, so the app never holds a piece
 *  of the exchange, and dropped the moment the device is registered. */
export type PendingLogin = {
  marketplace: AudibleMarketplace
  codeVerifier: string
  serial: string
  startedAt: Date
}

/** Everything the app needs to drive the Amazon sign-in in a web view: the page
 *  to load, the cookies to plant first — they are what makes the request look
 *  like the Audible iOS app, and without them Amazon challenges the sign-in far
 *  more often — and the redirect that carries the authorization code back. */
export type AudibleLogin = {
  url: string
  cookies: { name: string; value: string; domain: string }[]
  redirectUrl: string
}

/** One audiobook of the reader's Audible library, as it would be catalogued.
 *
 *  A proposal, not a record: the app lists these, the reader ticks the ones they
 *  want, and only then are books written. `alreadyInLibrary` is what lets the app
 *  leave the rest unticked instead of making the reader spot the duplicates. */
export type ImportableBook = {
  asin: AudibleAsin
  title: BookTitle
  authors: AuthorName[]
  /** Who reads the recording. Shown in the picker and carried onto the book:
   *  Audible is the only source that names them, and a cover never does. */
  narrators: NarratorName[]
  /** Audible's own running time, shown in the picker and carried onto the book:
   *  a library counts pages, and what an audiobook has instead is hours. */
  durationMinutes?: ListeningMinutes
  publisher?: Publisher
  synopsis?: Synopsis
  isbn13?: Isbn13
  /** The language of the recording, as Audible files it. Dropped when it names
   *  a language the closed list does not carry. */
  language?: BookLanguage
  coverUrl?: CoverUrl
  /** The shelf Audible files it under, mapped onto Shiori's closed list. Absent
   *  on a marketplace whose category ids are unknown, and for a shelf Shiori has
   *  no word for — an audience or a theme is not a genre. */
  genre?: Genre
  /** What the title's shelves say that no genre can hold — an audience
   *  ("Jeunesse") or a theme ("LGBTQ+"). Empty far more often than not. */
  subgenres: LocalizedSubgenre[]
  series?: SeriesMembership
  status: ReadingStatus
  /** When Audible says the listening ended. Carried onto the book so importing a
   *  decade of listening does not land every title on today's date and rewrite
   *  the reading statistics. */
  finishedAt?: Date
  alreadyInLibrary: boolean
}
