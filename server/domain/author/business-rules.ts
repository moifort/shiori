import { authorKeyOf } from '~/domain/author/primitives'
import type {
  Author,
  AuthorKey,
  AuthorSeries,
  AuthorWork,
  ShelvedAuthor,
} from '~/domain/author/types'
import { shelfDateOf } from '~/domain/book/business-rules'
import type { BookFormat, BookLanguage, ReadingStatus } from '~/domain/book/types'
import { isAudioSeries, seriesIdFor, seriesKeyOf } from '~/domain/series/primitives'
import type { SeriesId, SeriesState } from '~/domain/series/types'
import { Count } from '~/domain/shared/primitives'
import type { AuthorName } from '~/domain/shared/types'
import { slugify } from '~/utils/slug'

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

/** The sagas of an author's catalogue the reader holds no volume of in one
 *  format, each with the id its catalogue would be keyed on in that format, so a
 *  volume added from the author's page files into the saga the Series tab and
 *  the saga screen know. A saga read on paper and never heard is one to
 *  discover among the recordings: the saga heard is a saga of its own.
 *
 *  A saga the reader holds is recognised by that id, or by its folded name: a
 *  saga filed under another spelling of the author keeps another id, and must
 *  not come back as one to discover. */
export const sagasNotHeldOf = (
  catalogue: Pick<Author, 'name' | 'series'>,
  held: readonly { id: SeriesId; name: string }[],
  format: BookFormat,
): (AuthorSeries & { id: SeriesId })[] => {
  const heard = format === 'audiobook'
  const sameFormat = held.filter((saga) => isAudioSeries(saga.id) === heard)
  const heldIds = new Set(sameFormat.map((saga) => saga.id))
  const heldNames = new Set(sameFormat.map((saga) => slugify(saga.name)))
  return catalogue.series
    .map((saga) => ({ ...saga, id: seriesKeyOf(saga.name, catalogue.name, format) }))
    .filter((saga) => !heldIds.has(saga.id) && !heldNames.has(slugify(saga.name)))
}

/** How many sagas an author's books belong to, a saga read and heard counting
 *  once: the two are kept apart for their spines, but they are one work. */
export const sagaCountOf = (seriesIds: readonly SeriesId[]): number =>
  new Set(seriesIds.map((id) => seriesIdFor(id, 'book'))).size

/** The books outside any saga of an author's catalogue the reader does not hold,
 *  matched on the folded title against every book of theirs the reader has. */
export const worksNotHeldOf = (
  catalogue: Pick<Author, 'books'>,
  held: readonly { title: string }[],
): AuthorWork[] => {
  const titles = new Set(held.map((book) => slugify(book.title)))
  return catalogue.books.filter((work) => !titles.has(slugify(work.title)))
}

/** The reader's books of an author outside any saga: the read ones first, then
 *  the others, each group keeping the order it came in. */
export const standaloneBooksOf = <Book extends { series?: unknown; status: ReadingStatus }>(
  books: readonly Book[],
): Book[] => {
  const standalone = books.filter((book) => !book.series)
  return [
    ...standalone.filter((book) => book.status === 'read'),
    ...standalone.filter((book) => book.status !== 'read'),
  ]
}

/** The reader's sagas of an author as the page lists them: the ones they have
 *  read into first — in progress or finished — then the ones not started, then
 *  the ones set aside; the most recently shelved first within each. */
export const inPageOrder = <Saga extends { state: SeriesState | null; shelvedAt: Date }>(
  sagas: readonly Saga[],
): Saga[] => {
  const rank = (state: SeriesState | null) =>
    state === 'not-started' ? 1 : state === 'unfollowed' ? 2 : 0
  return [...sagas].sort(
    (left, right) =>
      rank(left.state) - rank(right.state) || right.shelvedAt.getTime() - left.shelvedAt.getTime(),
  )
}

/** The language most of the reader's books of an author are in: the edition the
 *  author's catalogue titles their works for. Undefined when none records one. */
export const mainLanguageOf = (
  books: readonly { language?: BookLanguage }[],
): BookLanguage | undefined => {
  const counts = new Map<BookLanguage, number>()
  for (const { language } of books)
    if (language) counts.set(language, (counts.get(language) ?? 0) + 1)
  let leading: BookLanguage | undefined
  for (const [language, count] of counts)
    if (leading === undefined || count > (counts.get(leading) ?? 0)) leading = language
  return leading
}
