import type { Brand } from 'ts-brand'
import type { SeriesId, SeriesName, VolumeKind, VolumeNumber } from '~/domain/series/types'
import type { Language } from '~/domain/shared/language'
import type { AuthorName, BookTitle, UserId, Year } from '~/domain/shared/types'
import type { ObjectPath, SignedUrl } from '~/system/object-store/types'

export type BookId = Brand<string, 'BookId'>
export type Publisher = Brand<string, 'Publisher'>
export type Isbn13 = Brand<string, 'Isbn13'>
export type Genre = Brand<string, 'Genre'>
export type Synopsis = Brand<string, 'Synopsis'>
export type PageCount = Brand<number, 'PageCount'>
/** One to five whole stars. Half stars double the value space without adding
 *  discernment, and shrink the touch target. */
export type StarRating = Brand<number, 'StarRating'>
export type ReadingNote = Brand<string, 'ReadingNote'>
/** Where the app loads a cover image from: the reader's own photo behind a signed
 *  URL, or the publisher's cover found by ISBN. Always HTTPS — iOS refuses to load
 *  anything else. */
export type CoverUrl = Brand<string, 'CoverUrl'>

/** Where a book stands for its reader. `reading` is where a book spends most of
 *  its life, and the only state in which a note actually gets written. */
export const READING_STATUSES = ['to-read', 'reading', 'read'] as const
export type ReadingStatus = (typeof READING_STATUSES)[number]

/** What kind of object the reader holds. Prose in print or on a screen, sound, or
 *  a drawn story — and among drawn stories, the three traditions a reader shelves
 *  apart: the Franco-Belgian album, the American comic, the manga. `book` is the
 *  default because it is what nearly every catalogued title is. */
export const BOOK_FORMATS = [
  'book',
  'ebook',
  'audiobook',
  'bande-dessinee',
  'comic',
  'manga',
] as const
export type BookFormat = (typeof BOOK_FORMATS)[number]

/** The book's place in a saga, denormalized onto the record. The name is copied
 *  here on purpose: grouping a 300-book library into sections must not read one
 *  catalogue document per row. */
export type SeriesMembership = {
  id: SeriesId
  name: SeriesName
  volume?: VolumeNumber
  kind: VolumeKind
}

/** A book as one reader holds it. Private, owned by exactly one user, never
 *  merged with anyone else's: two readers who scan the same novel keep two
 *  independent records. Public facts and personal judgment live side by side,
 *  because the record is the reader's, not the world's. */
export type Book = {
  id: BookId
  userId: UserId
  title: BookTitle
  authors: AuthorName[]
  format: BookFormat
  publisher?: Publisher
  firstPublishedIn?: Year
  synopsis?: Synopsis
  genres: Genre[]
  pageCount?: PageCount
  isbn13?: Isbn13
  /** The language of the edition on the shelf, not the app's language. */
  language?: Language
  series?: SeriesMembership
  /** Absent for a book added by hand or from a series catalogue: those have no
   *  photo, and the app draws a typographic placeholder instead. */
  coverPath?: ObjectPath
  /** The publisher's cover, found by ISBN when the book was scanned. Only drawn
   *  when there is no photo; absent when no cover was found, and the app then
   *  draws the placeholder. */
  publishedCoverUrl?: CoverUrl
  status: ReadingStatus
  rating?: StarRating
  note?: ReadingNote
  /** Excluded from any shared view. Built now, used when sharing ships, because
   *  adding a boolean to records already in production costs a migration. */
  hidden: boolean
  addedAt: Date
  startedAt?: Date
  finishedAt?: Date
}

/** A book as it is read back: the record plus the one URL its cover is drawn
 *  from, whichever source that turned out to be. The signed photo URL is not
 *  re-branded: in local development the object store signs plain-HTTP URLs, which
 *  `CoverUrl` rightly refuses as input but the dev app still has to draw. */
export type BookView = Book & { coverUrl?: SignedUrl | CoverUrl }

/** One section of the library: either a saga the reader owns several volumes of,
 *  or the standalone shelf. Derived per request, never stored. */
export type LibrarySection = {
  series?: { id: SeriesId; name: SeriesName }
  books: BookView[]
}
