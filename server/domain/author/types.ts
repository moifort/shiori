import type { Brand } from 'ts-brand'
import type { SeriesId } from '~/domain/series/types'
import type { AuthorName, Count } from '~/domain/shared/types'

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
  seriesIds: SeriesId[]
  /** Hearted books plus hearted sagas: what the tab is ranked on first. */
  favoriteCount: Count
  /** The mean of the stars given to their books and sagas. Absent when nothing
   *  of theirs is rated. */
  averageRating?: number
}
