import { AuthorUseCase, type FollowedAuthor } from '~/domain/author/use-case'
import { winnersOf, worksOf } from '~/domain/award/business-rules'
import { AwardQuery } from '~/domain/award/query'
import { AWARDS } from '~/domain/award/types'
import {
  heartedSagasOf,
  inLibraryView,
  isLovedBook,
  outsideHeartedSagas,
  sagaJudgementsOf,
  subgenresOf,
} from '~/domain/book/business-rules'
import { BookQuery } from '~/domain/book/query'
import type { BookFormat, BookLanguage, BookView, Subgenre } from '~/domain/book/types'
import {
  formatsOf,
  genreShelvesOf,
  pileFormatsOf,
  pileSectionsOf,
  RAIL_LIMIT,
  railsOf,
  shelvedInView,
} from '~/domain/library/business-rules'
import type { GenreShelf, PileSection, ShelvesView } from '~/domain/library/types'
import { type FollowedNarrator, NarratorUseCase } from '~/domain/narrator/use-case'
import { type FollowedSeries, SeriesUseCase } from '~/domain/series/use-case'
import { SeriesOpinionQuery } from '~/domain/series-opinion/query'
import type { UserId } from '~/domain/shared/types'

/** The most series cards and author or narrator portraits the entry screen's
 *  rails draw. */
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
  ): Promise<BookView[]> => {
    if (rail === 'favorites') return favorites(userId, view)
    return BookQuery.withSignedCovers(
      railsOf(shelvedInView(await BookQuery.all(userId), view))[rail],
    )
  }

  /** "Coups de cœur": what the reader loved, a volume left unrated judged by
   *  its saga — read beside the saga opinions. */
  const favorites = async (userId: UserId, view: ShelvesView): Promise<BookView[]> => {
    const [books, opinions] = await Promise.all([
      BookQuery.all(userId),
      SeriesOpinionQuery.all(userId),
    ])
    const sagas = sagaJudgementsOf(opinions)
    return BookQuery.withSignedCovers(
      shelvedInView(books, view)
        .filter((book) => isLovedBook(book, sagas))
        .slice(0, RAIL_LIMIT),
    )
  }

  /** "Coups de cœur" beside the hearted sagas: the hearted books, less the
   *  volumes of a saga the reader hearted, which `lovedSeries` draws whole. */
  export const favoritesBesideSeries = async (
    userId: UserId,
    view: ShelvesView,
  ): Promise<BookView[]> => {
    const [books, opinions] = await Promise.all([
      BookQuery.all(userId),
      SeriesOpinionQuery.all(userId),
    ])
    const sagas = sagaJudgementsOf(opinions)
    const hearted = heartedSagasOf(opinions)
    return BookQuery.withSignedCovers(
      shelvedInView(books, view)
        .filter((book) => isLovedBook(book, sagas) && outsideHeartedSagas(book, hearted))
        .slice(0, RAIL_LIMIT),
    )
  }

  /** The sagas of "Coups de cœur": those the reader hearted holding a book of
   *  the view, the one shelved last first. */
  export const lovedSeries = (userId: UserId, view: ShelvesView): Promise<FollowedSeries[]> =>
    SeriesUseCase.loved(userId, (book) => inLibraryView(book, view))

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

  /** The narrators rail, under the authors: who reads the view's recordings,
   *  the one shelved last first, with their faces. Empty when the view holds
   *  no audiobook. */
  export const narrators = (userId: UserId, view: ShelvesView): Promise<FollowedNarrator[]> =>
    NarratorUseCase.recent(userId, (book) => inLibraryView(book, view), PEOPLE_LIMIT)

  /** The pile's sections in a view: one scan of the library and the award
   *  winners Découvrir keeps, the covers of the books offered signed once
   *  however many sections hold them. */
  export const pileSections = async (
    userId: UserId,
    view: ShelvesView,
  ): Promise<PileSection<BookView>[]> => {
    const [books, found] = await Promise.all([BookQuery.all(userId), AwardQuery.foundWinners()])
    const sections = pileSectionsOf(
      books,
      worksOf(AWARDS, (award) => winnersOf(award, found)),
      view,
    )
    const offered = [
      ...new Map(sections.flatMap((s) => s.picks.map((p) => [p.book.id, p.book]))).values(),
    ]
    const signed = new Map(
      (await BookQuery.withSignedCovers(offered)).map((book) => [book.id, book]),
    )
    return sections.map((section) => ({
      kind: section.kind,
      picks: section.picks.flatMap((pick) => {
        const book = signed.get(pick.book.id)
        return book ? [{ ...pick, book }] : []
      }),
    }))
  }

  /** The format pills over the pile: the formats of its books and of those in
   *  progress, under a genre page those of the genre. */
  export const pileFormats = async (userId: UserId, view: ShelvesView): Promise<BookFormat[]> =>
    pileFormatsOf(await BookQuery.all(userId), view)
}
