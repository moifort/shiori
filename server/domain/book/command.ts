import { randomUUID } from 'node:crypto'
import type { WriteBatch } from 'firebase-admin/firestore'
import type { AudibleAsin } from '~/domain/audible/types'
import {
  datesAfterStatusChange,
  membershipFor,
  retaggedAfterEdit,
  statusAfterRating,
  statusStampAfterChange,
  storedRecommendation,
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
  Recommendation,
  SeriesMembership,
  SeriesPlacement,
  StarRating,
  Synopsis,
  TaggedSubgenre,
} from '~/domain/book/types'
import type { SeriesId, VolumeNumber } from '~/domain/series/types'
import { favoriteAfterRating, HEART_RATING } from '~/domain/shared/rating'
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
  subgenres?: TaggedSubgenre[]
  pageCount?: PageCount
  /** An audiobook's running time, which only an Audible import knows. */
  durationMinutes?: ListeningMinutes
  /** Where the Audible player last stopped, which only an import knows. */
  listenedMinutes?: ListeningMinutes
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
  /** When the book entered the reader's hands, for a book catalogued from
   *  elsewhere. An Audible import knows the day the title was bought, and the
   *  library is cut into months on that date: without it, a decade of purchases
   *  would all sit in the month of the import. Defaults to the moment of the
   *  write. */
  addedAt?: Date
}

/** The fields a reader may correct after the fact. Absent means untouched; the
 *  caller clears a field by passing null, which the GraphQL layer maps to
 *  undefined — Firestore rejects undefined, and the repository drops the key.
 *
 *  The saga is named rather than keyed: `series` says where the reader wants the
 *  book, and `membershipFor` decides which saga that is. Undefined takes the book
 *  out of its saga. */
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
  > & { series: SeriesPlacement }
>

export namespace BookCommand {
  export const add = async (
    userId: UserId,
    input: NewBook,
    now = new Date(),
    batch?: WriteBatch,
  ): Promise<Book> => {
    const addedAt = input.addedAt ?? now
    // A known finishing date stands in for the start as well. The reader never
    // told us when they began, and stamping today would put the start after the
    // end — which every statistic reads as a book finished before it was opened.
    // Failing that, the day the book arrived is the honest lower bound.
    const dates = datesAfterStatusChange(
      { status: 'to-read', startedAt: input.finishedAt ?? addedAt, finishedAt: input.finishedAt },
      input.status ?? 'to-read',
      now,
    )
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
      listenedMinutes: input.listenedMinutes,
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
      addedAt,
      updatedAt: now,
      // The status was set when the date it implies says so — finished, else
      // started, else added — not on the night a record was written about it.
      statusChangedAt: dates.finishedAt ?? dates.startedAt ?? addedAt,
      ...dates,
    }
    return repository.save(book, batch)
  }

  /** Move the dates a record was stamped with on arrival back to the day the
   *  book was in fact acquired.
   *
   *  Its own command rather than a field of `BookEdit`: the reader never types
   *  these dates, and the only thing that moves them is a machine learning,
   *  after the fact, when a title it imported was bought. `updatedAt` moves to
   *  now like any write; the reading dates are what is being corrected. */
  export const backdate = async (
    userId: UserId,
    bookId: BookId,
    dates: { addedAt: Date; startedAt?: Date; statusChangedAt?: Date },
    now = new Date(),
    batch?: WriteBatch,
  ): Promise<Book | 'not-found'> => {
    const book = await repository.findById(userId, bookId)
    if (!book) return 'not-found'
    return repository.save({ ...book, ...dates, updatedAt: now }, batch)
  }

  export const edit = async (
    userId: UserId,
    bookId: BookId,
    edit: BookEdit,
    now = new Date(),
    batch?: WriteBatch,
  ): Promise<Book | 'not-found' | 'no-author'> => {
    const book = await repository.findById(userId, bookId)
    if (!book) return 'not-found'
    const { series: placement, ...facts } = edit
    const retagged =
      'subgenres' in facts
        ? { subgenres: retaggedAfterEdit(facts.subgenres ?? [], book.subgenres) }
        : {}
    let membership: { series?: SeriesMembership } = {}
    if ('series' in edit) {
      const placed = placement
        ? membershipFor(
            placement,
            facts.authors ?? book.authors,
            book.series,
            (await repository.findAllByUser(userId)).flatMap((other) =>
              other.series ? [other.series] : [],
            ),
          )
        : undefined
      if (placed === 'no-author') return 'no-author'
      membership = { series: placed }
    }
    // A genre is a fact about the saga, not about one of its volumes: the
    // reader who corrects it on one book expects the whole shelf to follow,
    // rather than fixing fourteen records one by one. The volumes are looked up
    // before anything is written, so the scan never sees a half-written batch.
    const series = 'series' in edit ? membership.series : book.series
    const siblings =
      series && ('genre' in edit || 'subgenres' in edit)
        ? (await repository.findBySeries(userId, series.id)).filter((other) => other.id !== book.id)
        : []
    const edited = await repository.save(
      { ...book, ...facts, ...retagged, ...membership, updatedAt: now },
      batch,
    )
    const classification = {
      ...('genre' in edit ? { genre: edit.genre } : {}),
      ...('subgenres' in edit ? { subgenres: edited.subgenres } : {}),
    }
    for (const sibling of siblings)
      await repository.save({ ...sibling, ...classification, updatedAt: now }, batch)
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

  /** Give a book its rank in the saga it is already filed under.
   *
   *  Its own command rather than a field of `BookEdit`: an edit names the saga
   *  as the reader types it and keys it afresh, where this only fills the rank
   *  a machine learned after the fact — the volume an imported part was cut
   *  from. The saga itself is left exactly as it is. */
  export const numberInSeries = async (
    userId: UserId,
    bookId: BookId,
    volume: VolumeNumber,
    now = new Date(),
    batch?: WriteBatch,
  ): Promise<Book | 'not-found'> => {
    const book = await repository.findById(userId, bookId)
    if (!book?.series) return 'not-found'
    return repository.save({ ...book, series: { ...book.series, volume }, updatedAt: now }, batch)
  }

  /** Record where the Audible player last stopped in a recording.
   *
   *  Its own command rather than a field of `BookEdit`: the reader never types
   *  a position, and the only thing that moves it is the sync reading the
   *  player's own. */
  export const recordListening = async (
    userId: UserId,
    bookId: BookId,
    listenedMinutes: ListeningMinutes,
    now = new Date(),
    batch?: WriteBatch,
  ): Promise<Book | 'not-found'> => {
    const book = await repository.findById(userId, bookId)
    if (!book) return 'not-found'
    return repository.save({ ...book, listenedMinutes, updatedAt: now }, batch)
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
        favorite: favoriteAfterRating(book.favorite, rating),
        status,
        ...datesAfterStatusChange(book, status, now),
        ...statusStampAfterChange(book, status, now),
        updatedAt: now,
      },
      batch,
    )
  }

  /** Taking the stars back leaves the book read, with its dates: the reader is
   *  withdrawing a judgment, not saying the reading never happened. The heart
   *  goes with the stars it stood for. */
  export const unrate = async (
    userId: UserId,
    bookId: BookId,
    now = new Date(),
    batch?: WriteBatch,
  ): Promise<Book | 'not-found'> => {
    const book = await repository.findById(userId, bookId)
    if (!book) return 'not-found'
    return repository.save(
      { ...book, rating: undefined, favorite: undefined, updatedAt: now },
      batch,
    )
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

  /** Record who recommended the book, or forget it: passing none — or one that
   *  names nobody and says nothing — clears it. */
  export const recommend = async (
    userId: UserId,
    bookId: BookId,
    recommendation: Recommendation | undefined,
    now = new Date(),
    batch?: WriteBatch,
  ): Promise<Book | 'not-found'> => {
    const book = await repository.findById(userId, bookId)
    if (!book) return 'not-found'
    return repository.save(
      { ...book, recommendation: storedRecommendation(recommendation), updatedAt: now },
      batch,
    )
  }

  /** A heart is five stars: giving it rates the book five — which marks it read,
   *  as any rating does — and taking it back takes the stars with it. Stored
   *  only when true: a `false` on every record would be a field that means "the
   *  reader once looked at this and moved on". */
  export const setFavorite = async (
    userId: UserId,
    bookId: BookId,
    favorite: boolean,
    now = new Date(),
    batch?: WriteBatch,
  ): Promise<Book | 'not-found'> => {
    const book = await repository.findById(userId, bookId)
    if (!book) return 'not-found'
    if (!favorite)
      return repository.save(
        { ...book, favorite: undefined, rating: undefined, updatedAt: now },
        batch,
      )
    const status = statusAfterRating(book.status)
    return repository.save(
      {
        ...book,
        favorite: true,
        rating: HEART_RATING,
        status,
        ...datesAfterStatusChange(book, status, now),
        ...statusStampAfterChange(book, status, now),
        updatedAt: now,
      },
      batch,
    )
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

  /** Remove every volume of one saga from the reader's library, in one batch —
   *  or only the volumes of one edition, when `edition` names a language: a
   *  saga held in two languages is two sets of books, removed apart. Returns
   *  how many books went, and how many volumes of the saga remain. */
  export const removeSeries = async (
    userId: UserId,
    seriesId: SeriesId,
    edition: BookLanguage | undefined,
    batch?: WriteBatch,
  ): Promise<{ removed: number; remaining: number }> => {
    const volumes = await repository.findBySeries(userId, seriesId)
    const going = edition ? volumes.filter((volume) => volume.language === edition) : volumes
    for (const volume of going) await repository.remove(userId, volume.id, batch)
    return { removed: going.length, remaining: volumes.length - going.length }
  }

  /** Erase the reader's whole library — an account deletion wipes it outright. */
  export const deleteAllForUser = async (userId: UserId): Promise<void> =>
    repository.removeAllByUser(userId)
}
