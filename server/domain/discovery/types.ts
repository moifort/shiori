import type { AudibleAsin } from '~/domain/audible/types'
import type { AuthorKey } from '~/domain/author/types'
import type { FollowedAuthor } from '~/domain/author/use-case'
import type { AwaitedEditionView } from '~/domain/awaited-edition/types'
import type {
  BookFormat,
  BookLanguage,
  CoverUrl,
  DrawnFormat,
  Isbn13,
  ListeningMinutes,
  NarratorName,
  Publisher,
  Synopsis,
} from '~/domain/book/types'
import type { NarratorKey } from '~/domain/narrator/types'
import type { ScannedSeries, ScanResult } from '~/domain/scan/types'
import type { ReleaseDate, SagaKey, SeriesName, VolumeNumber } from '~/domain/series/types'
import type { FollowedSeries } from '~/domain/series/use-case'
import type { Language } from '~/domain/shared/language'
import type { AuthorName, BookTitle, UserId } from '~/domain/shared/types'

export type { ReleaseDate } from '~/domain/series/types'

/** The two ways a saga reaches a reader: printed or electronic, and recorded.
 *  Read off the saga's id — a saga heard is its own saga. */
export const RELEASE_FORMATS = ['book', 'audiobook'] as const
export type ReleaseFormat = (typeof RELEASE_FORMATS)[number]

/** A saga in the language one reader follows it in: what the web is searched
 *  for, and the key the shared watch is stored under. */
export type WatchedSaga = {
  seriesId: SagaKey
  language: BookLanguage
  /** The saga's name and author as the reader's books give them: what the web
   *  is searched with. */
  name: SeriesName
  author?: AuthorName
  /** A recording of the saga heard the reader holds in that language: the way
   *  into Audible's own listing of the series. */
  asin?: AudibleAsin
  /** The furthest numbered volume the reader holds in that language, and when
   *  they added it: a watch looked up before it was added and that does not
   *  list it is behind the reader's own shelf. */
  furthest?: { number: VolumeNumber; addedAt: Date }
}

/** One volume of a saga as the web found it in one language, out or announced. */
export type FoundVolume = {
  number: VolumeNumber
  title: BookTitle
  /** When it came out or comes out, as precisely as announced. Absent for a
   *  volume out on a date nobody found. */
  date?: ReleaseDate
  isbn13?: Isbn13
  /** The recording on Audible, kept only once Audible's own catalogue answered
   *  for it: a model's ASIN is never trusted as it is. */
  asin?: AudibleAsin
  /** The publisher's cover, found by the ISBN. */
  coverUrl?: CoverUrl
}

/** The saga a volume shown is of: what its release is named by. */
export type VolumeSaga = {
  seriesId: SagaKey
  name: SeriesName
  author?: AuthorName
  language: BookLanguage
}

/** A volume as a list shows it: with its saga, which its release is named by. */
export type ShownVolume = FoundVolume & { saga: VolumeSaga }

/** What exists or is announced of one saga in one language, as the web says —
 *  shared by every reader who follows it, keyed on the saga rather than on
 *  anybody, so the grounded call behind it is paid once every two weeks. */
export type SagaWatch = {
  /** `{seriesId}--{language}`. */
  key: string
  seriesId: SagaKey
  name: SeriesName
  author?: AuthorName
  language: BookLanguage
  checkedAt: Date
  /** Numbered volumes, in order, in the saga's own format. */
  volumes: FoundVolume[]
  /** Audible's own listing of the series was asked for on an Audible sync,
   *  whatever it answered: what keeps the sync from asking again every night.
   *  Carried over by every later look. */
  audibleListed?: true
}

/** What the hourly pass knows of one reader, so it reads their library once a
 *  day rather than every hour: the sagas they follow, and the alerts already
 *  pushed to them. */
export type DiscoveryReader = {
  userId: UserId
  /** The app's language, as the reader's last look at the tab said, since the
   *  scheduled passes have no request: what alerts are written in. */
  language: Language
  sagas: WatchedSaga[]
  /** When `sagas` was last worked out from the library. */
  syncedAt: Date
  /** `{watchKey}--{volume}`: an alert goes out once. */
  notified: string[]
  /** `{watchKey}--{volume}`: a volume is named in one weekly digest only.
   *  Absent on a reader stored before the digest existed. */
  announced?: string[]
  /** The authors they hold, in each format they hold them in. Absent on a
   *  reader stored before authors were watched. */
  authors?: WatchedAuthor[]
  /** The narrators they follow, in the language of the recordings they hold.
   *  Absent on a reader stored before narrators were watched. */
  narrators?: WatchedNarrator[]
}

/** What one saga has for the reader: the next volume announced they do not
 *  hold. The volumes already out are the saga screen's own, drawn from its
 *  catalogue. */
export type SagaReleases = {
  /** Whether the saga was ever looked up in that language: until it is, it
   *  has nothing to say, and opening it is what looks it up. */
  watched: boolean
  next?: ShownVolume
}

/** One row of the Découvrir tab: what the saga has for the reader, the
 *  numbers of the volumes out they have not added yet, and the ones of those
 *  just out that they can have now, the newest first. */
export type SagaDiscovery = SagaReleases & {
  series: FollowedSeries
  missing: VolumeNumber[]
  recent: ShownVolume[]
}

/** An author in one format and one language, as one reader holds them: what
 *  the web is searched for, and the key the shared watch is stored under. */
export type WatchedAuthor = {
  authorKey: AuthorKey
  /** The spelling the reader's books use: what the web is searched with. */
  name: AuthorName
  format: ReleaseFormat
  language: BookLanguage
}

/** A narrator in one language, as one reader holds them: what the web is
 *  searched for, and the key the shared watch is stored under. Recordings
 *  only: a narrator reads nothing else. */
export type WatchedNarrator = {
  narratorKey: NarratorKey
  /** The spelling the reader's recordings use: what the web is searched with. */
  name: NarratorName
  language: BookLanguage
}

/** One recording a narrator lent their voice to, out lately or announced. */
export type NarratedWork = FoundWork & {
  /** Who wrote it: what tells the reader's own copy from another book. */
  authors: AuthorName[]
}

/** What a narrator recorded lately or has announced in one language, as the
 *  web says — shared by every reader who follows them, keyed on the narrator
 *  rather than on anybody, so the grounded call behind it is paid once every
 *  three months. */
export type NarratorWatch = {
  /** `{narratorKey}--{language}`. */
  key: string
  narratorKey: NarratorKey
  name: NarratorName
  language: BookLanguage
  checkedAt: Date
  works: NarratedWork[]
}

/** One work of an author as the web found it in one language and format, out
 *  lately or announced. */
export type FoundWork = {
  title: BookTitle
  /** When it came out or comes out, as precisely as announced. */
  date?: ReleaseDate
  isbn13?: Isbn13
  /** The recording on Audible, kept only once Audible's own catalogue answered
   *  for it. */
  asin?: AudibleAsin
  coverUrl?: CoverUrl
  /** The saga it belongs to, as the web names it: what tells a new standalone
   *  from the next volume of a saga the reader already follows. */
  seriesName?: SeriesName
  volume?: VolumeNumber
  /** Set for a drawn story: an author can write both. */
  format?: DrawnFormat
}

/** What an author brought out lately or has announced in one language and
 *  format, as the web says — shared by every reader who holds them, keyed on
 *  the author rather than on anybody, so the grounded call behind it is paid
 *  once a month. */
export type AuthorWatch = {
  /** `{authorKey}--{format}--{language}`. */
  key: string
  authorKey: AuthorKey
  name: AuthorName
  format: ReleaseFormat
  language: BookLanguage
  checkedAt: Date
  works: FoundWork[]
}

/** One row of the Découvrir tab's Authors shelf: an author the reader holds,
 *  drawn as the Library's Authors shelf draws them, and what they have for
 *  the reader outside the sagas the reader already holds. */
/** What one author has for the reader in one format, outside the sagas they
 *  hold. */
export type AuthorReleases = {
  /** The soonest work announced. */
  next?: FoundWork
  /** The works out in the last three months, the newest first. */
  recent: FoundWork[]
  /** The reader's own editions of them awaited in that format that are
   *  announced or out, in the shelf's order. */
  awaited: AwaitedEditionView[]
}

export type AuthorDiscovery = AuthorReleases & {
  author: FollowedAuthor
  /** The language the author's works were looked up in. Absent on a row held
   *  only for what the reader awaits of them, which carries its own. */
  language?: BookLanguage
  /** The sagas of theirs among the tab's rows, with a volume announced or
   *  just out: the Books shelf's volumes are their news too. */
  sagas: SagaDiscovery[]
}

/** The Découvrir tab in one format. */
export type Discovery = {
  sagas: SagaDiscovery[]
  authors: AuthorDiscovery[]
  /** How many sagas and authors the reader follows in that format were never
   *  looked up: the app asks for them at once rather than wait for the hourly
   *  pass. */
  unwatched: number
  /** How many sagas and authors the reader follows in that format: none, and
   *  the app opens on the other format. */
  followed: number
}

/** A recording as Audible's own catalogue describes it, before anybody holds
 *  it. */
export type AudibleRecording = {
  title: BookTitle
  authors: AuthorName[]
  narrators: NarratorName[]
  publisher?: Publisher
  synopsis?: Synopsis
  durationMinutes?: ListeningMinutes
  coverUrl?: CoverUrl
}

/** A volume announced, described for its page before the reader adds it: the
 *  record a scan would propose, placed in its saga and edition, with what only
 *  a recording has. */
export type AnnouncedVolumePreview = {
  book: ScanResult
  narrators: NarratorName[]
  durationMinutes?: ListeningMinutes
  /** When it comes out, as precisely as announced. */
  releaseDate?: ReleaseDate
  /** The recording Audible confirmed, for its page on the reader's store. */
  asin?: AudibleAsin
}

/** A book Découvrir shows — a saga's volume, an edition awaited, an award
 *  winner — named by what the app already knows of it, to be described for
 *  its page. */
export type ReleaseSeed = {
  title: BookTitle
  authors: AuthorName[]
  format: BookFormat
  /** The edition's language. Absent, the book is described in the app's. */
  language?: BookLanguage
  series?: ScannedSeries
  /** The ISBN the web search found, for the model to check. */
  isbn13?: Isbn13
  /** When it comes or came out, as found. */
  releasedOn?: ReleaseDate
  coverUrl?: CoverUrl
}

/** A book described for its page: the record a scan would propose, and what
 *  only a recording has. */
export type ReleaseDescription = {
  book: ScanResult
  narrators: NarratorName[]
  durationMinutes?: ListeningMinutes
}

/** The watch keys of each kind, as the hourly pass groups them. */
export type WatchKeys = { sagas: string[]; authors: string[]; narrators: string[] }

/** What the hourly pass leaves for the next one, so that it asks Firestore for
 *  what can be due rather than for every watch: the keys every reader followed,
 *  and among them the ones that had no watch yet. Watches are only ever
 *  written, never deleted, so a key with no watch now either had none then or
 *  was not followed then. */
export type DiscoveryPassState = {
  followed: WatchKeys
  unwatched: WatchKeys
  savedAt: Date
}

/** The read model of the Découvrir tab: one reader's tab in one format, worked
 *  out once and read back whole, so opening the tab reads one document rather
 *  than the whole library, every catalogue and every watch it is drawn from.
 *  The projection writes it when the tab is opened while it is not fresh, and
 *  the hourly pass rewrites the ones its lookups or the new day made stale. */
export type DiscoveryProjection = DiscoveryProjectionState & { discovery: Discovery }

/** A projection without its rows: what says whether it is still fresh. */
export type DiscoveryProjectionState = {
  userId: UserId
  format: ReleaseFormat
  /** The app's language it was worked out in: another one works it out again. */
  language: Language
  /** The day its rows were dated against (`todayOf`): what is announced and
   *  what is out are told apart by it, so a new day works them out again. */
  day: string
  /** When the work started: whatever changed after it is not in the rows. */
  builtAt: Date
}

/** The last time something one reader's projections are drawn from changed:
 *  a mutation of theirs, a nightly sync of their library, or a watch of theirs
 *  looked up by the hourly pass. A projection built before it is stale. */
export type DiscoveryLibraryChange = { userId: UserId; changedAt: Date }
