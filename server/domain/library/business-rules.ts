import { coverSourcesOf, inLibraryView, isOnShelf, shelvedOf } from '~/domain/book/business-rules'
import { BOOK_FORMATS, type Book, type BookFormat } from '~/domain/book/types'
import type { GenreShelf, ShelvesView } from '~/domain/library/types'

/** The most covers a rail of the entry screen draws: a few screens' width, the
 *  rest a tap away on its own page. */
export const RAIL_LIMIT = 20

/** The books a view keeps, newest on the shelf first. A book given up on is
 *  left out: "Abandonnés" alone lists it. */
export const shelvedInView = <T extends Book>(books: readonly T[], view: ShelvesView): T[] =>
  shelvedOf(books.filter((book) => isOnShelf(book) && inLibraryView(book, view)))

/** The formats the library holds, in the order the pills list them: a pill
 *  that would empty every rail is never offered. */
export const formatsOf = (books: readonly Pick<Book, 'format'>[]): BookFormat[] => {
  const held = new Set(books.map((book) => book.format))
  return BOOK_FORMATS.filter((format) => held.has(format))
}

/** Each rail of the entry screen, from the books a view keeps (already in
 *  shelf order): what moved last, the pile and the books read, each the
 *  newest first and cut to a rail. "Coups de cœur" needs the saga opinions
 *  too, and is drawn by the use case. */
export const railsOf = <T extends Book>(shelved: readonly T[]) => ({
  recent: shelved.slice(0, RAIL_LIMIT),
  toRead: shelved.filter((book) => book.status === 'to-read').slice(0, RAIL_LIMIT),
  readRecently: shelved.filter((book) => book.status === 'read').slice(0, RAIL_LIMIT),
})

/** The genres of the books a view keeps, the most held first, then by name:
 *  the tiles of "Par genre". Each tile shows the cover of its book shelved
 *  last that has one. */
export const genreShelvesOf = <T extends Book>(
  shelved: readonly T[],
): (GenreShelf & {
  cover?: T
})[] => {
  const shelves = new Map<string, GenreShelf & { cover?: T }>()
  for (const book of shelved) {
    if (!book.genre) continue
    const shelf = shelves.get(book.genre) ?? { genre: book.genre, count: 0 }
    shelf.count += 1
    if (!shelf.cover && hasCover(book)) shelf.cover = book
    shelves.set(book.genre, shelf)
  }
  return [...shelves.values()].sort(
    (left, right) => right.count - left.count || left.genre.localeCompare(right.genre),
  )
}

const hasCover = (book: Book): boolean => {
  const sources = coverSourcesOf(book)
  return Boolean(sources.coverPath || sources.publishedCoverUrl)
}
