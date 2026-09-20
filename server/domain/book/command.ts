import { randomUUID } from 'node:crypto'
import type { WriteBatch } from 'firebase-admin/firestore'
import { datesAfterStatusChange, statusAfterRating } from '~/domain/book/business-rules'
import * as repository from '~/domain/book/infrastructure/repository'
import { BookId as BookIdOf } from '~/domain/book/primitives'
import type {
  Book,
  BookFormat,
  BookId,
  CoverUrl,
  Genre,
  Isbn13,
  ListeningMinutes,
  NarratorName,
  PageCount,
  Publisher,
  ReadingNote,
  ReadingStatus,
  SeriesMembership,
  StarRating,
  Subgenre,
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
  genre?: Genre
  subgenres?: Subgenre[]
  pageCount?: PageCount
  /** An audiobook's running time, which only an Audible import knows. */
  durationMinutes?: ListeningMinutes
  /** Who reads the recording. An import knows them; a scan reads a cover, which
   *  does not name its narrator. */
  narrators?: NarratorName[]
  isbn13?: Isbn13
  language?: Language
  series?: SeriesMembership
  coverPath?: ObjectPath
  publishedCoverUrl?: CoverUrl
  status?: ReadingStatus
  hidden?: boolean
  /** When the reading ended, for a book catalogued as already read. An import
   *  knows it and a scan does not: without it, a decade of Audible listening
   *  would land on today's date and rewrite every reading statistic. Ignored
   *  unless the status says the book is read. */
  finishedAt?: Date
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
    | 'genre'
    | 'subgenres'
    | 'pageCount'
    | 'narrators'
    | 'isbn13'
    | 'series'
  >
>

export namespace BookCommand {
  export const add = async (
    userId: UserId,
    input: NewBook,
    now = new Date(),
    batch?: WriteBatch,
  ): Promise<Book> => {
    const book: Book = {
      id: BookIdOf(randomUUID()),
      userId,
      title: input.title,
      authors: input.authors ?? [],
      format: input.format ?? 'book',
      publisher: input.publisher,
      firstPublishedIn: input.firstPublishedIn,
      synopsis: input.synopsis,
      genre: input.genre,
      subgenres: input.subgenres ?? [],
      pageCount: input.pageCount,
      durationMinutes: input.durationMinutes,
      narrators: input.narrators ?? [],
      isbn13: input.isbn13,
      language: input.language,
      series: input.series,
      coverPath: input.coverPath,
      publishedCoverUrl: input.publishedCoverUrl,
      // A book lands on the "to read" pile unless the reader says otherwise. It is
      // the only status that is true of every book the moment it is catalogued.
      status: input.status ?? 'to-read',
      hidden: input.hidden ?? false,
      addedAt: now,
      // A known finishing date stands in for the start as well. The reader never
      // told us when they began, and stamping today would put the start after the
      // end — which every statistic reads as a book finished before it was opened.
      ...datesAfterStatusChange(
        { status: 'to-read', startedAt: input.finishedAt, finishedAt: input.finishedAt },
        input.status ?? 'to-read',
        now,
      ),
    }
    return repository.save(book, batch)
  }

  export const edit = async (
    userId: UserId,
    bookId: BookId,
    edit: BookEdit,
    batch?: WriteBatch,
  ): Promise<Book | 'not-found'> => {
    const book = await repository.findById(userId, bookId)
    if (!book) return 'not-found'
    return repository.save({ ...book, ...edit }, batch)
  }

  export const setStatus = async (
    userId: UserId,
    bookId: BookId,
    status: ReadingStatus,
    now = new Date(),
    batch?: WriteBatch,
  ): Promise<Book | 'not-found'> => {
    const book = await repository.findById(userId, bookId)
    if (!book) return 'not-found'
    return repository.save({ ...book, status, ...datesAfterStatusChange(book, status, now) }, batch)
  }

  /** Rating a book marks it read: the reader is telling us they finished it, and
   *  leaving it on the "to read" pile would make every filter lie. */
  export const rate = async (
    userId: UserId,
    bookId: BookId,
    rating: StarRating,
    now = new Date(),
    batch?: WriteBatch,
  ): Promise<Book | 'not-found'> => {
    const book = await repository.findById(userId, bookId)
    if (!book) return 'not-found'
    const status = statusAfterRating()
    return repository.save(
      {
        ...book,
        rating,
        status,
        ...datesAfterStatusChange(book, status, now),
      },
      batch,
    )
  }

  /** Taking the stars back leaves the book read, with its dates: the reader is
   *  withdrawing a judgment, not saying the reading never happened. */
  export const unrate = async (
    userId: UserId,
    bookId: BookId,
    batch?: WriteBatch,
  ): Promise<Book | 'not-found'> => {
    const book = await repository.findById(userId, bookId)
    if (!book) return 'not-found'
    return repository.save({ ...book, rating: undefined }, batch)
  }

  /** Passing no note clears it. An emptied note is a deletion, not an empty
   *  string to store and later render as a blank block. */
  export const annotate = async (
    userId: UserId,
    bookId: BookId,
    note: ReadingNote | undefined,
    batch?: WriteBatch,
  ): Promise<Book | 'not-found'> => {
    const book = await repository.findById(userId, bookId)
    if (!book) return 'not-found'
    return repository.save({ ...book, note }, batch)
  }

  export const setHidden = async (
    userId: UserId,
    bookId: BookId,
    hidden: boolean,
    batch?: WriteBatch,
  ): Promise<Book | 'not-found'> => {
    const book = await repository.findById(userId, bookId)
    if (!book) return 'not-found'
    return repository.save({ ...book, hidden }, batch)
  }

  export const remove = async (
    userId: UserId,
    bookId: BookId,
    batch?: WriteBatch,
  ): Promise<'removed' | 'not-found'> => {
    const book = await repository.findById(userId, bookId)
    if (!book) return 'not-found'
    await repository.remove(userId, bookId, batch)
    return 'removed'
  }

  /** Erase the reader's whole library — an account deletion wipes it outright. */
  export const deleteAllForUser = async (userId: UserId): Promise<void> =>
    repository.removeAllByUser(userId)
}
