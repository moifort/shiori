import { groupedBySeries } from '~/domain/book/business-rules'
import * as repository from '~/domain/book/infrastructure/repository'
import type { Book, BookId, BookView, LibrarySection, ReadingStatus } from '~/domain/book/types'
import type { SeriesId } from '~/domain/series/types'
import type { UserId } from '~/domain/shared/types'
import { objectStore } from '~/system/object-store'

export namespace BookQuery {
  export const byId = async (userId: UserId, bookId: BookId): Promise<BookView | null> => {
    const book = await repository.findById(userId, bookId)
    return book ? await withCover(book) : null
  }

  /** The library, optionally narrowed to one reading status, grouped into series
   *  sections. Filtering happens before grouping so a status filter empties a
   *  saga's section rather than leaving an empty heading behind. */
  export const library = async (
    userId: UserId,
    status?: ReadingStatus,
  ): Promise<LibrarySection[]> => {
    const books = await repository.findAllByUser(userId)
    const kept = status ? books.filter((book) => book.status === status) : books
    return groupedBySeries(await withCovers(kept))
  }

  /** What the reader is reading right now, newest first — the home screen. */
  export const currentlyReading = async (userId: UserId): Promise<BookView[]> => {
    const books = await repository.findAllByUser(userId)
    const reading = books
      .filter((book) => book.status === 'reading')
      .sort((left, right) => startedAtOf(right) - startedAtOf(left))
    return withCovers(reading)
  }

  export const bySeries = async (userId: UserId, seriesId: SeriesId): Promise<Book[]> =>
    repository.findBySeries(userId, seriesId)

  export const all = async (userId: UserId): Promise<Book[]> => repository.findAllByUser(userId)
}

const startedAtOf = (book: Book) => (book.startedAt ?? book.addedAt).getTime()

// Cover URLs are signed one by one because each signature is a separate call, but
// a page of them is signed concurrently rather than in sequence: a 40-row library
// would otherwise pay 40 round trips end to end.
const withCovers = (books: readonly Book[]): Promise<BookView[]> =>
  Promise.all(books.map(withCover))

const withCover = async (book: Book): Promise<BookView> => {
  if (!book.coverPath) return book
  return { ...book, coverUrl: await objectStore().downloadUrl(book.coverPath) }
}
