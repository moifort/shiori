import type { Brand } from 'ts-brand'
import type { CoverUrl } from '~/domain/book/types'
import type { SagaKey, SeriesName, VolumeNumber } from '~/domain/series/types'
import type { AuthorName, BookTitle, Count, UserId, Year } from '~/domain/shared/types'

/** An author as the reader's library knows them, folded the way series keys are
 *  folded — diacritics dropped, punctuation collapsed — so "Tolkien, J.R.R." on
 *  one import and "J.R.R. Tolkien" on a scan still part ways, but "Émile Zola"
 *  and "Emile Zola" meet. Derived, never typed. */
export type AuthorKey = Brand<string, 'AuthorKey'>

/** An author the reader holds at least one book of. Derived per request from the
 *  books and the saga opinions, never stored: nothing about it is the reader's
 *  own word, and the day a shared author catalogue exists it will sit beside
 *  this, as `series/{seriesKey}` sits beside the books.
 *
 *  Generic over the book so the caller keeps whatever it passed in. */
export type ShelvedAuthor<Book> = {
  key: AuthorKey
  /** The spelling most of the reader's books use, the newest book breaking a tie. */
  name: AuthorName
  /** Every book of theirs the reader holds, newest shelved first. A book with
   *  two authors is on both. */
  books: Book[]
  /** The sagas those books belong to, each once. */
  seriesIds: SagaKey[]
  /** The date their newest book is shelved on — finished, else started, else
   *  added — which the list by activity is ordered on. */
  shelvedAt: Date
  /** Hearted books plus hearted sagas: what the tab is ranked on first. */
  favoriteCount: Count
  /** The mean of the stars given to their books and sagas. Absent when nothing
   *  of theirs is rated. */
  averageRating?: number
}

/** A few sentences on who the author is, written by the model in the language of
 *  whoever opened their page first — as a saga's description is. */
export type AuthorBiography = Brand<string, 'AuthorBiography'>
/** Where the author comes from, as a demonym in the language of the biography:
 *  "Américain", "Japonaise". */
export type Nationality = Brand<string, 'Nationality'>
/** The author's photograph as Wikipedia serves it. Always HTTPS, and never a URL
 *  the model wrote: models invent image URLs that 404. */
export type PortraitUrl = Brand<string, 'PortraitUrl'>

/** A saga the author wrote, as the author catalogue lists it: enough to draw a
 *  row for a saga the reader does not hold and to start it with its first volume. */
export type AuthorSeries = {
  name: SeriesName
  volumeCount?: VolumeNumber
  firstVolumeTitle?: BookTitle
  /** The first volume's cover, as Open Library shows the work. */
  coverUrl?: CoverUrl
}

/** A book the author wrote outside any saga. */
export type AuthorWork = {
  title: BookTitle
  publishedIn?: Year
  /** Its cover, as Open Library shows the work: often the original edition's
   *  rather than the reader's translation. */
  coverUrl?: CoverUrl
}

/** What the world knows of an author: a shared catalogue at `authors/{key}`,
 *  holding no reference to any reader, built the first time somebody opens the
 *  author's page and read by everyone after — the call that produced it is paid
 *  once, as a saga's is. It is never exposed through library sharing. */
export type Author = {
  key: AuthorKey
  name: AuthorName
  nationality?: Nationality
  birthYear?: Year
  deathYear?: Year
  biography?: AuthorBiography
  portraitUrl?: PortraitUrl
  /** When Wikipedia was last asked for a portrait it did not have. Absent once
   *  one is found, and on catalogues built before the lookup was retried. */
  portraitSoughtAt?: Date
  series: AuthorSeries[]
  books: AuthorWork[]
  cataloguedAt: Date
  /** The fields a reader corrected by hand, which no later catalogue call or
   *  portrait lookup writes over. Absent until the first correction. */
  corrected?: AuthorCorrectableField[]
}

/** What a reader may correct of an author's catalogue: the facts and the face.
 *  The name is the books', and the bibliography the model's. */
export const AUTHOR_CORRECTABLE_FIELDS = [
  'nationality',
  'birthYear',
  'deathYear',
  'biography',
  'portraitUrl',
] as const
export type AuthorCorrectableField = (typeof AUTHOR_CORRECTABLE_FIELDS)[number]

/** A reader's correction of an author's catalogue: a field absent is left
 *  alone, one set to undefined is cleared. */
export type AuthorCorrection = Partial<Pick<Author, AuthorCorrectableField>>

/** Where a portrait offered to the reader comes from. */
export type PortraitSource = 'wikipedia' | 'wikidata' | 'openLibrary' | 'web'

/** A portrait the reader may give an author, as the portrait picker offers it. */
export type PortraitChoice = { source: PortraitSource; url: PortraitUrl; isCurrent: boolean }

/** An author the catalogue call could not describe — it failed or found
 *  nothing. Remembered for good, so that no later opening waits on the same
 *  grounded call: the reader asks for another attempt when they want one. */
export type AuthorMiss = {
  key: AuthorKey
  missedAt: Date
}

/** An author the reader hearted: theirs alone, never shared. Absent when they
 *  have not, rather than stored as "not hearted". */
export type AuthorFavorite = { userId: UserId; authorKey: AuthorKey; favoritedAt: Date }
