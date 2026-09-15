import { randomUUID } from 'node:crypto'
import { datesAfterStatusChange, statusAfterRating } from '~/domain/book/business-rules'
import * as repository from '~/domain/book/infrastructure/repository'
import { BookId as BookIdOf } from '~/domain/book/primitives'
import type {
  Book,
  BookFormat,
  BookId,
  Genre,
  Isbn13,
  PageCount,
  Publisher,
  ReadingNote,
  ReadingStatus,
  SeriesMembership,
  StarRating,
  Synopsis,
} from '~/domain/book/types'
import type { Language } from '~/domain/shared/language'
import type { AuthorName, BookTitle, UserId, Year } from '~/domain/shared/types'
import type { ObjectPath } from '~/system/object-store/types'

/** Everything a book can be created with. Only a title is required: a book added
 *  by hand from a half-remembered recommendation is still a book, and refusing it
 *  for want of an author would push the reader back to a notes app. */
export type NewBook = {
  title: BookTitle
  authors?: AuthorName[]
  format?: BookFormat
  publisher?: Publisher
  firstPublishedIn?: Year
  synopsis?: Synopsis
  genres?: Genre[]
  pageCount?: PageCount
  isbn13?: Isbn13
  language?: Language
  series?: SeriesMembership
  coverPath?: ObjectPath
  status?: ReadingStatus
  hidden?: boolean
}

/** The fields a reader may correct after the fact. Absent means untouched; the
 *  caller clears a field by passing null, which the GraphQL layer maps to
 *  undefined — Firestore rejects undefined, and the repository drops the key. */
export type BookEdit = Partial<
  Pick<
    Book,
    | 'title'
    | 'authors'
    | 'format'
    | 'publisher'
    | 'firstPublishedIn'
    | 'synopsis'
    | 'genres'
    | 'pageCount'
    | 'isbn13'
    | 'series'
  >
>

export namespace BookCommand {
  export const add = async (userId: UserId, input: NewBook, now = new Date()): Promise<Book> => {
    const book: Book = {
      id: BookIdOf(randomUUID()),
      userId,
      title: input.title,
      authors: input.authors ?? [],
      format: input.format ?? 'book',
      publisher: input.publisher,
      firstPublishedIn: input.firstPublishedIn,
      synopsis: input.synopsis,
      genres: input.genres ?? [],
      pageCount: input.pageCount,
      isbn13: input.isbn13,
      language: input.language,
      series: input.series,
      coverPath: input.coverPath,
      // A book lands on the "to read" pile unless the reader says otherwise. It is
      // the only status that is true of every book the moment it is catalogued.
      status: input.status ?? 'to-read',
      hidden: input.hidden ?? false,
      addedAt: now,
      ...datesAfterStatusChange(
        { status: 'to-read', startedAt: undefined, finishedAt: undefined },
        input.status ?? 'to-read',
        now,
      ),
    }
    return repository.save(book)
  }

  export const edit = async (
    userId: UserId,
    bookId: BookId,
    edit: BookEdit,
  ): Promise<Book | 'not-found'> => {
    const book = await repository.findById(userId, bookId)
    if (!book) return 'not-found'
    return repository.save({ ...book, ...edit })
  }

  export const setStatus = async (
    userId: UserId,
    bookId: BookId,
    status: ReadingStatus,
    now = new Date(),
  ): Promise<Book | 'not-found'> => {
    const book = await repository.findById(userId, bookId)
    if (!book) return 'not-found'
    return repository.save({ ...book, status, ...datesAfterStatusChange(book, status, now) })
  }

  /** Rating a book marks it read: the reader is telling us they finished it, and
   *  leaving it on the "to read" pile would make every filter lie. */
  export const rate = async (
    userId: UserId,
    bookId: BookId,
    rating: StarRating,
    now = new Date(),
  ): Promise<Book | 'not-found'> => {
    const book = await repository.findById(userId, bookId)
    if (!book) return 'not-found'
    const status = statusAfterRating()
    return repository.save({
      ...book,
      rating,
      status,
      ...datesAfterStatusChange(book, status, now),
    })
  }

  /** Passing no note clears it. An emptied note is a deletion, not an empty
   *  string to store and later render as a blank block. */
  export const annotate = async (
    userId: UserId,
    bookId: BookId,
    note: ReadingNote | undefined,
  ): Promise<Book | 'not-found'> => {
    const book = await repository.findById(userId, bookId)
    if (!book) return 'not-found'
    return repository.save({ ...book, note })
  }

  export const setHidden = async (
    userId: UserId,
    bookId: BookId,
    hidden: boolean,
  ): Promise<Book | 'not-found'> => {
    const book = await repository.findById(userId, bookId)
    if (!book) return 'not-found'
    return repository.save({ ...book, hidden })
  }

  export const remove = async (
    userId: UserId,
    bookId: BookId,
  ): Promise<'removed' | 'not-found'> => {
    const book = await repository.findById(userId, bookId)
    if (!book) return 'not-found'
    await repository.remove(userId, bookId)
    return 'removed'
  }

  /** Erase the reader's whole library — an account deletion wipes it outright. */
  export const deleteAllForUser = async (userId: UserId): Promise<void> =>
    repository.removeAllByUser(userId)
}
