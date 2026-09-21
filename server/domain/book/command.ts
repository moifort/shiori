import { randomUUID } from 'node:crypto'
import type { WriteBatch } from 'firebase-admin/firestore'
import type { AudibleAsin } from '~/domain/audible/types'
import {
  datesAfterStatusChange,
  statusAfterRating,
  statusStampAfterChange,
} from '~/domain/book/business-rules'
import * as repository from '~/domain/book/infrastructure/repository'
import { BookId as BookIdOf } from '~/domain/book/primitives'
import type {
  Book,
  BookFormat,
  BookId,
  BookLanguage,
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
import type { SeriesId } from '~/domain/series/types'
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
  /** The language of the edition, which the scan reads off the cover. */
  language?: BookLanguage
  /** The Audible title the record stands for. Only an import supplies it, and it
   *  is what lets the nightly sync find this very book again. */
  audibleAsin?: AudibleAsin
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
    | 'durationMinutes'
    | 'narrators'
    | 'isbn13'
    | 'language'
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
      audibleAsin: input.audibleAsin,
      series: input.series,
      coverPath: input.coverPath,
      publishedCoverUrl: input.publishedCoverUrl,
      // A book lands on the "to read" pile unless the reader says otherwise. It is
      // the only status that is true of every book the moment it is catalogued.
      status: input.status ?? 'to-read',
      hidden: input.hidden ?? false,
      addedAt: now,
      updatedAt: now,
      statusChangedAt: now,
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
    now = new Date(),
    batch?: WriteBatch,
  ): Promise<Book | 'not-found'> => {
    const book = await repository.findById(userId, bookId)
    if (!book) return 'not-found'
    const edited = await repository.save({ ...book, ...edit, updatedAt: now }, batch)
    // A genre is a fact about the saga, not about one of its volumes: the
    // reader who corrects it on one book expects the whole shelf to follow,
    // rather than fixing fourteen records one by one.
    if (book.series && ('genre' in edit || 'subgenres' in edit)) {
      const classification = {
        ...('genre' in edit ? { genre: edit.genre } : {}),
        ...('subgenres' in edit ? { subgenres: edit.subgenres ?? [] } : {}),
      }
      const siblings = (await repository.findBySeries(userId, book.series.id)).filter(
        (other) => other.id !== book.id,
      )
      for (const sibling of siblings)
        await repository.save({ ...sibling, ...classification, updatedAt: now }, batch)
    }
    return edited
  }

  /** Record which Audible title a book stands for.
   *
   *  Its own command rather than a field of `BookEdit`: the reader never types an
   *  ASIN, and the only thing that fills it is a machine recognizing a book it
   *  imported before the link existed. */
  export const linkToAudible = async (
    userId: UserId,
    bookId: BookId,
    audibleAsin: AudibleAsin,
    now = new Date(),
    batch?: WriteBatch,
  ): Promise<Book | 'not-found'> => {
    const book = await repository.findById(userId, bookId)
    if (!book) return 'not-found'
    return repository.save({ ...book, audibleAsin, updatedAt: now }, batch)
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
    return repository.save(
      {
        ...book,
        status,
        ...datesAfterStatusChange(book, status, now),
        ...statusStampAfterChange(book, status, now),
        updatedAt: now,
      },
      batch,
    )
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
    const status = statusAfterRating(book.status)
    return repository.save(
      {
        ...book,
        rating,
        status,
        ...datesAfterStatusChange(book, status, now),
        ...statusStampAfterChange(book, status, now),
        updatedAt: now,
      },
      batch,
    )
  }

  /** Taking the stars back leaves the book read, with its dates: the reader is
   *  withdrawing a judgment, not saying the reading never happened. */
  export const unrate = async (
    userId: UserId,
    bookId: BookId,
    now = new Date(),
    batch?: WriteBatch,
  ): Promise<Book | 'not-found'> => {
    const book = await repository.findById(userId, bookId)
    if (!book) return 'not-found'
    return repository.save({ ...book, rating: undefined, updatedAt: now }, batch)
  }

  /** Passing no note clears it. An emptied note is a deletion, not an empty
   *  string to store and later render as a blank block. */
  export const annotate = async (
    userId: UserId,
    bookId: BookId,
    note: ReadingNote | undefined,
    now = new Date(),
    batch?: WriteBatch,
  ): Promise<Book | 'not-found'> => {
    const book = await repository.findById(userId, bookId)
    if (!book) return 'not-found'
    return repository.save({ ...book, note, updatedAt: now }, batch)
  }

  /** Stored only when true. A book that is not a favourite has nothing to say
   *  about it, and a `false` on every record would be a field that means
   *  "the reader once looked at this and moved on". */
  export const setFavorite = async (
    userId: UserId,
    bookId: BookId,
    favorite: boolean,
    now = new Date(),
    batch?: WriteBatch,
  ): Promise<Book | 'not-found'> => {
    const book = await repository.findById(userId, bookId)
    if (!book) return 'not-found'
    return repository.save({ ...book, favorite: favorite || undefined, updatedAt: now }, batch)
  }

  export const setHidden = async (
    userId: UserId,
    bookId: BookId,
    hidden: boolean,
    now = new Date(),
    batch?: WriteBatch,
  ): Promise<Book | 'not-found'> => {
    const book = await repository.findById(userId, bookId)
    if (!book) return 'not-found'
    return repository.save({ ...book, hidden, updatedAt: now }, batch)
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

  /** Remove every volume of one saga from the reader's library, in one batch.
   *  Returns how many books went. */
  export const removeSeries = async (
    userId: UserId,
    seriesId: SeriesId,
    batch?: WriteBatch,
  ): Promise<number> => {
    const volumes = await repository.findBySeries(userId, seriesId)
    for (const volume of volumes) await repository.remove(userId, volume.id, batch)
    return volumes.length
  }

  /** Erase the reader's whole library — an account deletion wipes it outright. */
  export const deleteAllForUser = async (userId: UserId): Promise<void> =>
    repository.removeAllByUser(userId)
}
