import type { Brand } from 'ts-brand'
import type { AudibleAsin } from '~/domain/audible/types'
import type { SeriesId, SeriesName, VolumeKind, VolumeNumber } from '~/domain/series/types'
import type { AuthorName, BookTitle, UserId, Year } from '~/domain/shared/types'
import type { ObjectPath, SignedUrl } from '~/system/object-store/types'

export type BookId = Brand<string, 'BookId'>
export type Publisher = Brand<string, 'Publisher'>
export type Isbn13 = Brand<string, 'Isbn13'>
/** One free label refining the genre: "dark fantasy", "space opera", "shōnen".
 *  Written by the model in the scan language, or typed by the reader. */
export type Subgenre = Brand<string, 'Subgenre'>
export type Synopsis = Brand<string, 'Synopsis'>
export type PageCount = Brand<number, 'PageCount'>
/** How long an audiobook runs, in whole minutes. Kept on the record rather than
 *  derived: it is what the listening statistics count, the way pages are what the
 *  reading statistics count. Only Audible fills it — a scanned cover does not say
 *  how long the recording is. */
export type ListeningMinutes = Brand<number, 'ListeningMinutes'>
/** Who reads an audiobook aloud. Its own type rather than an `AuthorName`: a
 *  narrator is not an author, and a library that conflated the two would credit
 *  the wrong person on every recording. */
export type NarratorName = Brand<string, 'NarratorName'>
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

/** What the book is about, from a closed list. Closed on purpose: free labels
 *  come back as "Fantasy" on one scan and "Fantasy épique" on the next, and no
 *  statistic survives that. Nuance lives in subgenres. Audience ("jeunesse") is
 *  not a genre, and the object (manga, comic) is the format. */
export const GENRES = [
  'fantasy',
  'science-fiction',
  'horror',
  'crime',
  'thriller',
  'romance',
  'historical-fiction',
  'adventure',
  'literary-fiction',
  'humor',
  'poetry',
  'drama',
  'biography',
  'history',
  'essay',
  'science',
  'self-help',
  'business',
  'art',
  'cooking',
  'travel',
  'other',
] as const
export type Genre = (typeof GENRES)[number]

/** The language an edition is printed or recorded in, from a closed list.
 *  Closed for the reason genres are closed, plus one of its own: the app draws a
 *  flag for each, and an arbitrary ISO code has no flag to draw.
 *
 *  A language whose edition is not on this list keeps no language at all, rather
 *  than an `other` that would be a second way of saying "unknown". */
export const BOOK_LANGUAGES = [
  'fr',
  'en',
  'es',
  'de',
  'it',
  'pt',
  'nl',
  'sv',
  'pl',
  'ru',
  'uk',
  'tr',
  'ar',
  'ja',
  'zh',
  'ko',
] as const
export type BookLanguage = (typeof BOOK_LANGUAGES)[number]

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
  /** Absent for a book added by hand, which had no model to classify it. */
  genre?: Genre
  /** Ordered, most representative first: a library row has space for one
   *  subgenre and takes the head of this list, so the order is data. */
  subgenres: Subgenre[]
  pageCount?: PageCount
  /** An audiobook's running time. Absent on anything else, and absent on an
   *  audiobook catalogued by hand or by scan, which had no source for it. */
  durationMinutes?: ListeningMinutes
  /** Who reads the recording. Empty on anything but an audiobook, and empty on
   *  an audiobook whose source never said — a cover does not name its narrator. */
  narrators: NarratorName[]
  isbn13?: Isbn13
  /** The language of the edition on the shelf, not the app's language. Absent on
   *  every book catalogued before the scan started reading it, and on any edition
   *  in a language the closed list does not carry. */
  language?: BookLanguage
  /** The Audible title this record stands for, when it has one.
   *
   *  What the nightly sync moves a status on, and the reason it can: a shelf key
   *  says "the reader already owns this story", which is all a duplicate check
   *  needs, but it is far too loose to write into somebody's reading record night
   *  after night. Only a book carrying an ASIN is ever touched by Audible, so a
   *  printed edition scanned from a photo stays the reader's alone.
   *
   *  Absent on everything but an imported audiobook, and on imports that predate
   *  the field — the first sync matches those by shelf key and fills it in once. */
  audibleAsin?: AudibleAsin
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
  /** A book the reader keeps close, decoupled from the rating on purpose: a
   *  five-star novel one never wants to open again and a three-star one kept for
   *  what it meant at the time are both real, and one field cannot say both. */
  favorite?: boolean
  note?: ReadingNote
  /** Excluded from any shared view. Built now, used when sharing ships, because
   *  adding a boolean to records already in production costs a migration. */
  hidden: boolean
  addedAt: Date
  /** Stamped by every write the reader or a sync makes to the record. Absent on
   *  records written before the field existed. */
  updatedAt?: Date
  /** When the book last moved between the pile, the reading and the read. What
   *  the library is ordered on: the shelf whose book was last picked up or put
   *  down comes first, and correcting a publisher or writing a note moves
   *  nothing. Absent on records from before the field existed, which then rank
   *  on the date their current status implies. */
  statusChangedAt?: Date
  startedAt?: Date
  finishedAt?: Date
}

/** A book as it is read back: the record plus the one URL its cover is drawn
 *  from, whichever source that turned out to be. The signed photo URL is not
 *  re-branded: in local development the object store signs plain-HTTP URLs, which
 *  `CoverUrl` rightly refuses as input but the dev app still has to draw. */
export type BookView = Book & { coverUrl?: SignedUrl | CoverUrl }

/** One section of the library: either a saga the reader owns several volumes of,
 *  or the standalone shelf. Derived per request, never stored.
 *
 *  A saga held in two languages makes two sections. The editions on a shelf are
 *  different objects — different translations, different covers, read at
 *  different times — and stacking them under one heading hid that. */
export type LibrarySection = {
  series?: { id: SeriesId; name: SeriesName; language?: BookLanguage }
  /** What the reader makes of the saga, when they have said anything: drawn on
   *  the section heading. Absent on the standalone shelf. */
  opinion?: { rating?: StarRating; favorite: boolean }
  books: BookView[]
}
