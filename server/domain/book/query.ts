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

  export const bySeries = async (userId: UserId, seriesId: SeriesId): Promise<Book[]> =>
    repository.findBySeries(userId, seriesId)

  export const all = async (userId: UserId): Promise<Book[]> => repository.findAllByUser(userId)
}

// Cover URLs are signed one by one because each signature is a separate call, but
// a page of them is signed concurrently rather than in sequence: a 40-row library
// would otherwise pay 40 round trips end to end.
const withCovers = (books: readonly Book[]): Promise<BookView[]> =>
  Promise.all(books.map(withCover))

// The reader's own photo wins over the publisher's cover: it is the edition on
// their shelf. Neither is a guarantee the image loads, so the app keeps its
// placeholder for a URL that fails.
const withCover = async (book: Book): Promise<BookView> => {
  if (book.coverPath) return { ...book, coverUrl: await objectStore().downloadUrl(book.coverPath) }
  return book.publishedCoverUrl ? { ...book, coverUrl: book.publishedCoverUrl } : book
}
