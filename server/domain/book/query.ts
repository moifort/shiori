import {
  groupedBySeries,
  ratedShelfOf,
  seriesRatingsOf,
  shelfPageOf,
  shelvedOf,
  subgenresOf,
} from '~/domain/book/business-rules'
import * as repository from '~/domain/book/infrastructure/repository'
import type {
  Book,
  BookId,
  BookLanguage,
  BookView,
  LibrarySection,
  ReadingStatus,
  Subgenre,
} from '~/domain/book/types'
import type { SeriesId } from '~/domain/series/types'
import { SeriesOpinionQuery } from '~/domain/series-opinion/query'
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
    const sections = groupedBySeries(await withCovers(kept))
    // One scan of the reader's opinions for every heading, rather than a lookup
    // per saga: a reader with forty sagas would otherwise pay forty reads.
    const opinions = new Map(
      (await SeriesOpinionQuery.all(userId)).map((opinion) => [opinion.seriesId, opinion]),
    )
    return sections.map((section) => {
      const opinion = section.series && opinions.get(section.series.id)
      return opinion
        ? { ...section, opinion: { rating: opinion.rating, favorite: opinion.favorite ?? false } }
        : section
    })
  }

  /** One page of the Library tab: the reader's books in the order the tab
   *  draws them, optionally narrowed to their favourites, to the rated ones —
   *  best first, a saga's rating standing in for its unrated volumes — or to
   *  one status. Covers are signed for the page only — a 300-book library
   *  would otherwise pay 300 signatures to draw 60 rows. */
  export const libraryPage = async (
    userId: UserId,
    page: { limit: number; after?: BookId },
    view: { favorite?: boolean; rated?: boolean; status?: ReadingStatus },
  ): Promise<{ books: BookView[]; hasMore: boolean }> => {
    const kept = (await repository.findAllByUser(userId)).filter(
      (book) =>
        (!view.favorite || book.favorite === true) && (!view.status || book.status === view.status),
    )
    const ordered = view.rated
      ? ratedShelfOf(kept, seriesRatingsOf(await SeriesOpinionQuery.all(userId)))
      : shelvedOf(kept)
    const { books, hasMore } = shelfPageOf(ordered, page.limit, page.after)
    return { books: await withCovers(books), hasMore }
  }

  export const bySeries = async (userId: UserId, seriesId: SeriesId): Promise<Book[]> =>
    repository.findBySeries(userId, seriesId)

  export const all = async (userId: UserId): Promise<Book[]> => repository.findAllByUser(userId)

  /** A reader's books as somebody else may see them: everything they did not
   *  mark "do not share". The one place the `hidden` flag is enforced, so a
   *  shared view cannot forget it.
   *
   *  Covers are not signed here: a profile draws three shortlists out of a whole
   *  library, and signing four hundred URLs to show thirty is four hundred calls
   *  for nothing. Pass what will actually be drawn through `withSignedCovers`. */
  export const shared = async (userId: UserId): Promise<Book[]> =>
    (await repository.findAllByUser(userId)).filter((book) => !book.hidden)

  /** Sign the covers of the books that are about to be drawn. */
  export const withSignedCovers = (books: readonly Book[]): Promise<BookView[]> => withCovers(books)

  /** The reader's own subgenre vocabulary, for the edit form to propose. */
  export const subgenres = async (userId: UserId, language: BookLanguage): Promise<Subgenre[]> =>
    subgenresOf(await repository.findAllByUser(userId), language)
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
