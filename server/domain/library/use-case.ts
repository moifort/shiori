import { AuthorUseCase, type FollowedAuthor } from '~/domain/author/use-case'
import { inLibraryView, subgenresOf } from '~/domain/book/business-rules'
import { BookQuery } from '~/domain/book/query'
import type { BookFormat, BookLanguage, BookView, Subgenre } from '~/domain/book/types'
import { formatsOf, genreShelvesOf, railsOf, shelvedInView } from '~/domain/library/business-rules'
import type { GenreShelf, ShelvesView } from '~/domain/library/types'
import { type FollowedSeries, SeriesUseCase } from '~/domain/series/use-case'
import type { UserId } from '~/domain/shared/types'

/** The most series cards and author portraits the entry screen's rails draw. */
const PEOPLE_LIMIT = 12

/** The most subgenre pills a genre page offers: the most used ones. */
const SUBGENRE_LIMIT = 12

export type ShelfRail = 'recent' | 'toRead' | 'readRecently' | 'favorites'

/** The Library tab's entry screen, one rail at a time: each reads the library
 *  scan the request shares, so asking for every rail costs one scan, and the
 *  covers signed are those of the rail alone. */
export namespace LibraryUseCase {
  /** The formats the reader holds, under a genre page those of its books:
   *  the pills offered. Never narrowed by the format pill itself, which would
   *  leave only the one chosen. */
  export const formats = async (userId: UserId, view: ShelvesView): Promise<BookFormat[]> =>
    formatsOf(
      (await BookQuery.all(userId)).filter((book) =>
        inLibraryView(book, { genre: view.genre, subgenre: view.subgenre }),
      ),
    )

  export const rail = async (
    userId: UserId,
    view: ShelvesView,
    rail: ShelfRail,
  ): Promise<BookView[]> =>
    BookQuery.withSignedCovers(railsOf(shelvedInView(await BookQuery.all(userId), view))[rail])

  /** Whether the view holds a book given up on: the "Abandonnés" row shows
   *  only then. */
  export const hasDropped = async (userId: UserId, view: ShelvesView): Promise<boolean> =>
    (await BookQuery.all(userId)).some(
      (book) => book.status === 'dropped' && inLibraryView(book, view),
    )

  /** The tiles of "Par genre", each with its cover signed. */
  export const genres = async (
    userId: UserId,
    view: ShelvesView,
  ): Promise<(GenreShelf & { cover?: BookView })[]> => {
    const shelves = genreShelvesOf(shelvedInView(await BookQuery.all(userId), view))
    const covers = new Map(
      (await BookQuery.withSignedCovers(shelves.flatMap((shelf) => shelf.cover ?? []))).map(
        (book) => [book.id, book],
      ),
    )
    return shelves.map((shelf) => ({
      genre: shelf.genre,
      count: shelf.count,
      cover: shelf.cover && covers.get(shelf.cover.id),
    }))
  }

  /** The subgenre pills of a genre page, the most used first, in the reader's
   *  language. None outside a genre page. */
  export const subgenres = async (
    userId: UserId,
    view: ShelvesView,
    language: BookLanguage,
  ): Promise<Subgenre[]> => {
    if (!view.genre) return []
    const books = (await BookQuery.all(userId)).filter((book) =>
      inLibraryView(book, { format: view.format, genre: view.genre }),
    )
    return subgenresOf(books, language).slice(0, SUBGENRE_LIMIT)
  }

  /** The series rail: the sagas holding a book of the view, the one shelved
   *  last first, those set aside left out. */
  export const series = (userId: UserId, view: ShelvesView): Promise<FollowedSeries[]> =>
    SeriesUseCase.followedRecent(userId, (book) => inLibraryView(book, view), PEOPLE_LIMIT)

  /** The authors rail: the authors of the view's books, the one shelved last
   *  first, with their portraits. */
  export const authors = (userId: UserId, view: ShelvesView): Promise<FollowedAuthor[]> =>
    AuthorUseCase.recent(userId, (book) => inLibraryView(book, view), PEOPLE_LIMIT)
}
