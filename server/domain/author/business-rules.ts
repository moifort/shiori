import { authorKeyOf } from '~/domain/author/primitives'
import type { AuthorKey, ShelvedAuthor } from '~/domain/author/types'
import { shelfDateOf } from '~/domain/book/business-rules'
import type { SeriesId } from '~/domain/series/types'
import { Count } from '~/domain/shared/primitives'
import type { AuthorName } from '~/domain/shared/types'

type AuthoredBook = {
  authors: AuthorName[]
  series?: { id: SeriesId }
  rating?: number
  favorite?: boolean
  addedAt: Date
  startedAt?: Date
  finishedAt?: Date
}

type SagaOpinion = { seriesId: SeriesId; rating?: number; favorite?: boolean }

/** Every author the library holds a book of, with what the reader made of them.
 *
 *  A book with several authors is on each of them: the reader who loved
 *  Good Omens loved it by Pratchett and by Gaiman alike. A saga counts for an
 *  author as soon as one of their books belongs to it, so its heart and stars
 *  are theirs too — the saga is their work. */
export const shelvedAuthorsOf = <Book extends AuthoredBook>(
  books: readonly Book[],
  opinions: readonly SagaOpinion[],
): ShelvedAuthor<Book>[] => {
  const opinionOf = new Map(opinions.map((opinion) => [opinion.seriesId, opinion]))
  const byKey = new Map<AuthorKey, { books: Book[]; spellings: Map<AuthorName, number> }>()
  for (const book of newestShelvedFirst(books)) {
    // A book listing the same author twice is still one book of theirs.
    const keys = new Set<AuthorKey>()
    for (const name of book.authors) {
      const key = authorKeyOf(name)
      const known = byKey.get(key) ?? {
        books: [] as Book[],
        spellings: new Map<AuthorName, number>(),
      }
      if (!keys.has(key)) known.books.push(book)
      keys.add(key)
      known.spellings.set(name, (known.spellings.get(name) ?? 0) + 1)
      byKey.set(key, known)
    }
  }
  return [...byKey].map(([key, { books, spellings }]) => {
    const seriesIds = [...new Set(books.flatMap((book) => (book.series ? [book.series.id] : [])))]
    const sagaOpinions = seriesIds.flatMap((id) => opinionOf.get(id) ?? [])
    const ratings = [...books, ...sagaOpinions].flatMap((judged) =>
      judged.rating === undefined ? [] : [judged.rating],
    )
    return {
      key,
      name: mostUsedSpelling(spellings),
      books,
      seriesIds,
      favoriteCount: Count(
        [...books, ...sagaOpinions].filter((judged) => judged.favorite === true).length,
      ),
      averageRating:
        ratings.length === 0
          ? undefined
          : ratings.reduce((sum, rating) => sum + rating, 0) / ratings.length,
    }
  })
}

/** The Authors tab's order: the authors the reader loves first. Hearts first,
 *  since a heart is the one mark given on purpose; then the stars' mean; then
 *  how much of theirs the reader holds; then the name, so two authors who tie
 *  on everything keep a stable place between two pages.
 *
 *  Done on the server rather than on the phone because the list is paginated:
 *  ordered on the client, a page landing late would reshuffle what is drawn. */
export const inAuthorOrder = <Author extends ShelvedAuthor<unknown>>(
  authors: readonly Author[],
): Author[] =>
  [...authors].sort(
    (left, right) =>
      right.favoriteCount - left.favoriteCount ||
      (right.averageRating ?? 0) - (left.averageRating ?? 0) ||
      right.books.length - left.books.length ||
      left.name.localeCompare(right.name),
  )

/** The authors a view of the tab keeps: every one, or those with a heart. */
export const matchingAuthorFilter = <Author extends { favoriteCount: number }>(
  authors: readonly Author[],
  filter: { favorite?: boolean },
): Author[] =>
  filter.favorite ? authors.filter((author) => author.favoriteCount > 0) : [...authors]

const newestShelvedFirst = <Book extends AuthoredBook>(books: readonly Book[]): Book[] =>
  [...books].sort((left, right) => shelfDateOf(right).getTime() - shelfDateOf(left).getTime())

/** The spelling used most, the first met — the newest book — breaking a tie. */
const mostUsedSpelling = (spellings: ReadonlyMap<AuthorName, number>): AuthorName => {
  let chosen: AuthorName | undefined
  for (const [name, count] of spellings)
    if (chosen === undefined || count > (spellings.get(chosen) ?? 0)) chosen = name
  if (chosen === undefined) throw new Error('an author is only ever made from a spelling')
  return chosen
}
