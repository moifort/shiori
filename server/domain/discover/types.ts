import type { AudibleMarketplace } from '~/domain/audible/types'
import type { Book, BookLanguage, CoverUrl, Isbn13 } from '~/domain/book/types'
import type { ReleaseDate, SeriesId, VolumeNumber } from '~/domain/series/types'
import type { FollowedSeries } from '~/domain/series/use-case'
import type { Language } from '~/domain/shared/language'
import type { AuthorName, BookTitle, UserId } from '~/domain/shared/types'
import type { SignedUrl } from '~/system/object-store/types'

export type { ReleaseDate } from '~/domain/series/types'

/** What the reader follows, in one language the web is searched in: a saga in
 *  the language they read it in — its next volume — and in the app's when that
 *  differs — its translation; a book on its own read in another language, in
 *  the app's. Worked out from the library on every look, never stored. */
export type WatchedWork = {
  /** `series--{seriesId}--{language}` or `book--{shelfKey}--{language}`: what
   *  "Pas intéressé" remembers, and what the shared watch is keyed on. */
  key: string
  kind: 'series' | 'book'
  seriesId?: SeriesId
  /** The saga's name, or the book's title, as the reader catalogued it. */
  title: BookTitle
  author?: AuthorName
  /** The language the web is searched in. */
  language: BookLanguage
  /** The language the reader read it in. */
  readIn: BookLanguage
  /** The volumes of a saga the reader read or is reading, in order. */
  volumesRead: VolumeNumber[]
  /** The cover of the reader's own copy, for a row with no edition cover. */
  cover: Pick<Book, 'coverPath' | 'publishedCoverUrl'>
  /** The last time the reader touched it, the most recent first. */
  lastActivity: number
}

/** The two ways a book reaches a reader: printed or electronic, and recorded. */
export type ReleaseFormat = 'book' | 'audiobook'

/** One edition of a work in one language, out or announced. */
export type ReleaseEdition = {
  title: BookTitle
  volume?: VolumeNumber
  format: ReleaseFormat
  /** When it came out or comes out. Absent for an edition out on a date
   *  nobody found. */
  date?: ReleaseDate
  isbn13?: Isbn13
  /** The publisher's cover, found by the ISBN. */
  coverUrl?: CoverUrl
}

/** What exists or is announced of one work in one language, as the web says —
 *  shared by every reader who follows the same work, keyed on it rather than
 *  on anybody, so the grounded call behind it is paid once a week. */
export type ReleaseWatch = {
  key: string
  kind: WatchedWork['kind']
  title: BookTitle
  author?: AuthorName
  language: BookLanguage
  checkedAt: Date
  /** The saga's name or the book's title in that language. Absent when the web
   *  found none. */
  localTitle?: BookTitle
  editions: ReleaseEdition[]
}

/** An edition with an exact date, kept so the daily alert pass needs no model
 *  call and no library read. */
export type DatedEdition = {
  /** What `notified` remembers. */
  key: string
  workKey: string
  title: BookTitle
  volume?: VolumeNumber
  format: ReleaseFormat
  date: ReleaseDate
  /** The edition's language. */
  language: BookLanguage
  /** Whether it is a translation of what the reader read, rather than the
   *  next volume in the language they read it in. */
  translation: boolean
}

/** A reader's Découvrir tab as the daily refresh left it. The shared watches
 *  and the library are read alongside it on every look. */
export type DiscoverFeed = {
  userId: UserId
  /** The app's language, as the last request from the reader said, since the
   *  scheduled refresh has no request: what translations are looked for in. */
  language: Language
  /** When the daily refresh last ran. Absent before the first. */
  refreshedAt?: Date
  /** The editions with an exact date, for the alerts. */
  dated: DatedEdition[]
  /** Work keys the reader is not interested in: never proposed again. */
  dismissed: string[]
  /** Edition keys already pushed, so an alert goes out once. */
  notified: string[]
}

/** One work on the tab, in one language: what exists or is coming of it. */
export type Release = {
  key: string
  kind: WatchedWork['kind']
  seriesId?: SeriesId
  /** The language of its editions. */
  language: BookLanguage
  /** The language the reader read it in. */
  readIn: BookLanguage
  /** Its title in that language, else the one the reader knows. */
  title: BookTitle
  author?: AuthorName
  coverUrl?: CoverUrl | SignedUrl
  /** Every edition the reader does not own, by volume then by date. */
  editions: ReleaseEdition[]
  /** The soonest edition still to come. */
  nextDate?: ReleaseDate
  /** The Audible store the reader's account was opened on, where a recording
   *  is looked for. Absent for a reader with no Audible connection, who is
   *  never offered a recording. */
  audibleMarketplace?: AudibleMarketplace
  /** A saga as the Series tab draws its row in that language. A language the
   *  reader holds nothing in answers a row with no books of its own. */
  series?: FollowedSeries
}

/** The tab as it is served. */
export type Discover = {
  preparedAt?: Date
  /** Whether the reader may ask for a fresh look now: once a day at most. */
  canRefresh: boolean
  /** Works with an edition still to come, the soonest first. */
  upcoming: Release[]
  /** Works the reader may want: for now, a translation already out of what
   *  they read in another language, the most recently read first. */
  maybe: Release[]
}
