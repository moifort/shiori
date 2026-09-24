import type { Brand } from 'ts-brand'
import type { AudibleAsin, AudibleMarketplace } from '~/domain/audible/types'
import type { Book, BookLanguage, CoverUrl, Isbn13 } from '~/domain/book/types'
import type { VolumeNumber } from '~/domain/series/types'
import type { Language } from '~/domain/shared/language'
import type { AuthorName, BookTitle, UserId } from '~/domain/shared/types'
import type { SignedUrl } from '~/system/object-store/types'

/** When a book comes out, as precisely as anybody announced it: a year, a
 *  month, or a day. An alert only ever goes out on a day. */
export type ReleaseDate = Brand<string, 'ReleaseDate'>

/** What the reader read in a language other than the app's, and would want in
 *  the app's own: a saga as a whole, or one book on its own. Worked out from the
 *  library on every look, never stored. */
export type ForeignWork = {
  /** `series--{seriesId}` or `book--{shelfKey}`: what "Pas intéressé"
   *  remembers, and what the shared watch is keyed on. */
  key: string
  kind: 'series' | 'book'
  /** The saga's name, or the book's title, as the reader catalogued it. */
  title: BookTitle
  author?: AuthorName
  /** The language the reader read it in. */
  language: BookLanguage
  /** The volumes of a saga the reader read or is reading, in order. */
  volumesRead: VolumeNumber[]
  /** The cover of the reader's own copy, for a row with no translated cover. */
  cover: Pick<Book, 'coverPath' | 'publishedCoverUrl'>
  /** The last time the reader touched it, the most recent first on the tab. */
  lastActivity: number
}

/** The two ways a translation reaches a reader: printed or electronic, and
 *  recorded. */
export type TranslationFormat = 'book' | 'audiobook'

/** One edition of a work in the app's language, out or announced. */
export type TranslatedEdition = {
  title: BookTitle
  volume?: VolumeNumber
  format: TranslationFormat
  /** When it came out or comes out. Absent for an edition out on a date
   *  nobody found. */
  date?: ReleaseDate
  isbn13?: Isbn13
  audibleAsin?: AudibleAsin
  coverUrl?: CoverUrl
}

/** What exists or is announced of one work in one language, as the web says —
 *  shared by every reader who read the same work, keyed on it rather than on
 *  anybody, so the grounded call behind it is paid once a week. */
export type TranslationWatch = {
  key: string
  kind: ForeignWork['kind']
  title: BookTitle
  author?: AuthorName
  language: Language
  checkedAt: Date
  /** The saga's name or the book's title in that language, which is how
   *  Audible's listing is matched to the work. Absent when untranslated. */
  translatedTitle?: BookTitle
  editions: TranslatedEdition[]
}

/** The recordings the reader's own Audible marketplace lists for one work. */
export type AudibleTranslations = { workKey: string; editions: TranslatedEdition[] }

/** An edition with an exact date, kept so the daily alert pass needs no model
 *  call and no library read. */
export type DatedEdition = {
  /** What `notified` remembers. */
  key: string
  workKey: string
  title: BookTitle
  volume?: VolumeNumber
  format: TranslationFormat
  date: ReleaseDate
}

/** A reader's Découvrir tab as the daily refresh left it. The shared watches
 *  and the library are read alongside it on every look. */
export type DiscoverFeed = {
  userId: UserId
  /** The language translations are looked for in: the app's, as the last
   *  request from the reader said, since the scheduled refresh has no request. */
  language: Language
  /** When the daily refresh last ran. Absent before the first. */
  refreshedAt?: Date
  /** What the reader's Audible marketplace lists. Absent for a reader with no
   *  Audible connection, who is never offered a recording. */
  audible?: { marketplace: AudibleMarketplace; works: AudibleTranslations[] }
  /** The editions with an exact date, for the alerts. */
  dated: DatedEdition[]
  /** Work keys the reader is not interested in: never proposed again. */
  dismissed: string[]
  /** Edition keys already pushed, so an alert goes out once. */
  notified: string[]
}

/** One work on the tab: what the reader read, and what exists or is coming of
 *  it in their language. */
export type Translation = {
  key: string
  kind: ForeignWork['kind']
  /** Its title in the app's language, else the one the reader knows. */
  title: BookTitle
  originalTitle: BookTitle
  author?: AuthorName
  originalLanguage: BookLanguage
  volumesRead: VolumeNumber[]
  coverUrl?: CoverUrl | SignedUrl
  /** Every edition, by volume then by date. */
  editions: TranslatedEdition[]
  /** The soonest edition still to come. */
  nextDate?: ReleaseDate
  /** Where the reader's Audible marketplace sells a recording. */
  audibleMarketplace?: AudibleMarketplace
}

/** The tab as it is served. */
export type Discover = {
  preparedAt?: Date
  /** Whether the reader may ask for a fresh look now: once a day at most. */
  canRefresh: boolean
  /** Works with at least one edition still to come, the soonest first. */
  upcoming: Translation[]
  /** Works already out in the app's language, the most recently read first. */
  available: Translation[]
}
