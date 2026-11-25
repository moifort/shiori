import type {
  BookFormat,
  BookId,
  BookLanguage,
  BookMedium,
  CoverUrl,
  Isbn13,
  PageCount,
  Publisher,
  ReadingNote,
  StarRating,
} from '~/domain/book/types'
import type { SeriesName, VolumeNumber } from '~/domain/series/types'
import type { AuthorName, BookTitle, UserId, Year } from '~/domain/shared/types'

/** The shelf a Goodreads book sits on: every book is on exactly one of the
 *  three Goodreads keeps, `read`, `currently-reading` and `to-read`. */
export type GoodreadsShelf = 'read' | 'currently-reading' | 'to-read'

/** One line of a Goodreads library export, read and checked. Everything but
 *  the title and the shelf may be absent: a hand-added Goodreads book carries
 *  no ISBN, and a book never rated has a rating of 0, which means none. */
export type GoodreadsRow = {
  /** The title and first author folded together, as the duplicate check folds
   *  them: what the app ticks and sends back. */
  key: string
  title: BookTitle
  authors: AuthorName[]
  /** "The Way of Kings (The Stormlight Archive, #1)" names its saga. */
  series?: { name: SeriesName; volume?: VolumeNumber }
  isbn13?: Isbn13
  rating?: StarRating
  publisher?: Publisher
  format: BookFormat
  media: BookMedium[]
  pageCount?: PageCount
  firstPublishedIn?: Year
  readOn?: Date
  addedOn?: Date
  shelf: GoodreadsShelf
  /** A shelf of the reader's own saying they gave it up: "dnf", "abandoned". */
  dropped: boolean
  review?: ReadingNote
}

/** What the reader decides on the preview before anything is written. */
export type GoodreadsChoices = {
  /** The keys of the rows to import: unticked rows are left out. */
  keys: readonly string[]
  /** Where `to-read` goes: the wishlist, which is what most readers keep that
   *  shelf for, or the pile, for a reader who owns those books. */
  toRead: 'wishlist' | 'pile'
  keepRatings: boolean
  keepDates: boolean
  keepReviews: boolean
  /** Uncertain rows the reader said are the book they already hold. */
  sameBooks: readonly string[]
}

/** How a row stands against the library it would join. */
export type GoodreadsVerdict = 'new' | 'held' | 'uncertain'

/** A row as the preview shows it. */
export type GoodreadsPreviewRow = GoodreadsRow & {
  verdict: GoodreadsVerdict
  /** The record a held or uncertain row would complete. */
  heldBookId?: BookId
  heldTitle?: BookTitle
  heldCoverUrl?: CoverUrl
  /** An Open Library address guessed from the ISBN, never fetched here: it
   *  answers 404 when there is no cover, and the app draws its stand-in. */
  coverGuess?: CoverUrl
  language?: BookLanguage
}

export type GoodreadsPreview = {
  rows: GoodreadsPreviewRow[]
  /** How many books each shelf holds, `dropped` counted apart from `read`. */
  shelves: { read: number; reading: number; toRead: number; dropped: number }
  rated: number
  dated: number
  reviewed: number
}

/** The file is not a Goodreads export, or holds no book. */
export type UnreadableGoodreadsExport = 'not-goodreads' | 'empty'

/** What an import did, kept for the settings page and the covers pass. */
export type GoodreadsImport = {
  userId: UserId
  importedAt: Date
  /** Books created. */
  imported: number
  /** Books already held that took the Goodreads stars, dates or review. */
  completed: number
  /** Wishes created from `to-read`. */
  wished: number
  /** Books still waiting for their published cover to be sought. */
  pendingCovers: BookId[]
  /** Books whose cover no source had: they keep the app's stand-in. */
  withoutCover: number
}

export type GoodreadsImportOutcome = {
  imported: number
  completed: number
  wished: number
  pendingCovers: number
}
