import type { Brand } from 'ts-brand'
import type { AudibleAsin } from '~/domain/audible/types'
import type {
  BookFormat,
  BookId,
  BookLanguage,
  CoverUrl,
  Genre,
  Isbn13,
  Synopsis,
} from '~/domain/book/types'
import type { AlertKind } from '~/domain/notification/types'
import type { SeriesName, VolumeNumber } from '~/domain/series/types'
import type { Language } from '~/domain/shared/language'
import type { AuthorName, BookTitle, UserId, Year } from '~/domain/shared/types'
import type { SignedUrl } from '~/system/object-store/types'

/** When a book comes out, as precisely as anybody announced it: a year, a
 *  month, or a day. An alert only ever goes out on a day. */
export type ReleaseDate = Brand<string, 'ReleaseDate'>

/** A book the tab proposes, with the one line that says why. */
export type Suggestion = {
  /** Title and first author folded, as the shelf key: what "Pas pour moi"
   *  remembers, and how a book the reader already owns is left out. */
  key: string
  title: BookTitle
  authors: AuthorName[]
  firstPublishedIn?: Year
  language?: BookLanguage
  format: BookFormat
  genre?: Genre
  series?: { name: SeriesName; volume?: VolumeNumber }
  synopsis?: Synopsis
  coverUrl?: CoverUrl
  isbn13?: Isbn13
  audibleAsin?: AudibleAsin
  /** Why this book, for this reader, in their language. */
  reason: string
  /** The prize it won, "Hugo 2024". */
  award?: string
  /** What readers worldwide make of it, out of five, and how many said so. */
  publicRating?: number
  ratingCount?: number
  releaseDate?: ReleaseDate
}

/** A book coming out that the reader has a reason to care about. */
export type Release = Suggestion & {
  kind: AlertKind
  date: ReleaseDate
}

/** "Parce que vous avez aimé X": one shelf per book the reader loved. */
export type LovedShelf = { anchor: BookTitle; items: Suggestion[] }

/** A reader's Découvrir tab as the weekly refresh left it. The friends' hearts
 *  are not stored here: they are read live, since a friend's heart of this
 *  morning belongs on the tab this afternoon. */
export type DiscoverFeed = {
  userId: UserId
  /** The language suggestions are written in: the app's, as the last request
   *  from the reader said, since the scheduled refresh has no request. */
  language: Language
  /** When the weekly refresh last ran. Absent before the first. */
  refreshedAt?: Date
  audible: Suggestion[]
  releases: Release[]
  becauseYouLoved: LovedShelf[]
  offTrail: Suggestion[]
  /** The reader's leading genres, whose award and acclaim lists are shared
   *  documents read alongside this one. */
  genres: Genre[]
  /** Suggestion keys the reader dismissed or took: never proposed again. */
  dismissed: string[]
  /** Release keys already pushed, so an alert goes out once. */
  notified: string[]
}

/** The award winners and the acclaimed books of one genre, in one language —
 *  shared by every reader who leans that way, so the call is paid once. */
export type GenreList = {
  key: string
  genre: Genre
  language: Language
  refreshedAt: Date
  awards: Suggestion[]
  acclaimed: Suggestion[]
}

/** What the release tracker watches: a saga, an author, or the French
 *  translation of one book. */
export type ReleaseSubject =
  | { kind: 'series'; name: SeriesName; author?: AuthorName; language?: BookLanguage }
  | { kind: 'author'; author: AuthorName }
  | { kind: 'translation'; title: BookTitle; author?: AuthorName }

/** The announced releases of one subject, shared by every reader who follows
 *  it, refreshed weekly. */
export type ReleaseWatch = {
  key: string
  subject: ReleaseSubject
  checkedAt: Date
  releases: WatchedRelease[]
}

export type WatchedRelease = {
  title: BookTitle
  authors: AuthorName[]
  volume?: VolumeNumber
  date: ReleaseDate
  format: 'book' | 'audiobook'
  language?: BookLanguage
  isbn13?: Isbn13
}

/** A friend's hearted book the reader does not own, with every friend who
 *  hearted it. The first friend is the one whose copy opens. */
export type FriendFavorite = {
  key: string
  friendId: UserId
  bookId: BookId
  friendNames: string[]
  title: BookTitle
  authors: AuthorName[]
  format: BookFormat
  series?: { name: SeriesName; volume?: VolumeNumber }
  coverUrl?: CoverUrl | SignedUrl
}

/** The tab as it is served. */
export type Discover = {
  preparedAt?: Date
  /** Whether the reader may ask for a fresh set now: once a day at most. */
  canRefresh: boolean
  friendsFavorites: FriendFavorite[]
  audible: Suggestion[]
  releases: Release[]
  becauseYouLoved: LovedShelf[]
  awards: Suggestion[]
  acclaimed: Suggestion[]
  offTrail: Suggestion[]
}
