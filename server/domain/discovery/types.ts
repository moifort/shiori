import type { AudibleAsin } from '~/domain/audible/types'
import type { AuthorKey } from '~/domain/author/types'
import type { FollowedAuthor } from '~/domain/author/use-case'
import type { AwaitedEditionView } from '~/domain/awaited-edition/types'
import type {
  BookLanguage,
  CoverUrl,
  Isbn13,
  ListeningMinutes,
  NarratorName,
  Publisher,
  Synopsis,
} from '~/domain/book/types'
import type { ScanResult } from '~/domain/scan/types'
import type { ReleaseDate, SeriesId, SeriesName, VolumeNumber } from '~/domain/series/types'
import type { FollowedSeries } from '~/domain/series/use-case'
import type { Language } from '~/domain/shared/language'
import type { AuthorName, BookTitle, UserId } from '~/domain/shared/types'

export type { ReleaseDate } from '~/domain/series/types'

/** The two ways a saga reaches a reader: printed or electronic, and recorded.
 *  Read off the saga's id — a saga heard is its own saga. */
export type ReleaseFormat = 'book' | 'audiobook'

/** A saga in the language one reader follows it in: what the web is searched
 *  for, and the key the shared watch is stored under. */
export type WatchedSaga = {
  seriesId: SeriesId
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

/** What exists or is announced of one saga in one language, as the web says —
 *  shared by every reader who follows it, keyed on the saga rather than on
 *  anybody, so the grounded call behind it is paid once every two weeks. */
export type SagaWatch = {
  /** `{seriesId}--{language}`. */
  key: string
  seriesId: SeriesId
  name: SeriesName
  author?: AuthorName
  language: BookLanguage
  checkedAt: Date
  /** Numbered volumes, in order, in the saga's own format. */
  volumes: FoundVolume[]
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
}

/** What one saga has for the reader: the next volume announced they do not
 *  hold. The volumes already out are the saga screen's own, drawn from its
 *  catalogue. */
export type SagaReleases = {
  /** Whether the saga was ever looked up in that language: until it is, it
   *  has nothing to say, and opening it is what looks it up. */
  watched: boolean
  next?: FoundVolume
}

/** One row of the Découvrir tab: what the saga has for the reader, the
 *  numbers of the volumes out they have not added yet, and the ones of those
 *  just out that they can have now, the newest first. */
export type SagaDiscovery = SagaReleases & {
  series: FollowedSeries
  missing: VolumeNumber[]
  recent: FoundVolume[]
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
