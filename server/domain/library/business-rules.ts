import { authorKeyOf } from '~/domain/author/primitives'
import type { AwardedWork } from '~/domain/award/types'
import {
  coverSourcesOf,
  inLibraryView,
  isOnShelf,
  sameAuthor,
  shelvedOf,
} from '~/domain/book/business-rules'
import { BOOK_FORMATS, type Book, type BookFormat } from '~/domain/book/types'
import type { GenreShelf, PilePick, PileSection, ShelvesView } from '~/domain/library/types'
import { narratorKeyOf } from '~/domain/narrator/primitives'
import type { NarratorKey } from '~/domain/narrator/types'
import { slugify } from '~/utils/slug'

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

/** The most books a section of the pile offers: a rail a few screens wide.
 *  The rest of the pile is on "Toute la pile". */
export const PILE_SECTION_LIMIT = 15

/** The fewest stars that make an author or a narrator a favourite: a heart
 *  counts too, whatever it sits on. */
export const FAVORITE_RATING = 4

const isFavorite = (book: Pick<Book, 'favorite' | 'rating'>): boolean =>
  book.favorite === true || (book.rating !== undefined && book.rating >= FAVORITE_RATING)

/** When a book in progress was begun, for the oldest to come first. */
const startedOf = (book: Book): number =>
  (book.startedAt ?? book.statusChangedAt ?? book.addedAt).getTime()

/** The sections of the pile, from the whole library: the history decides
 *  (what was read, rated, begun), the view narrows what is offered. A section
 *  left empty is left out, and a book may sit in several, each giving its own
 *  reason to read it. Nothing here calls anything: the award winners are the
 *  list Découvrir already keeps. */
export const pileSectionsOf = <T extends Book>(
  books: readonly T[],
  works: readonly AwardedWork[],
  view: ShelvesView,
  heartedNarrators: ReadonlySet<NarratorKey> = new Set(),
): PileSection<T>[] => {
  const offered = books.filter((book) => inLibraryView(book, view))
  const pile = shelvedOf(offered.filter((book) => book.status === 'to-read'))
  const read = books.filter((book) => book.status === 'read')
  const picks = (kept: readonly T[]): PilePick<T>[] => kept.map((book) => ({ book }))

  const sections: PileSection<T>[] = [
    {
      kind: 'to-finish',
      picks: picks(
        offered
          .filter((book) => book.status === 'reading')
          .sort((left, right) => startedOf(left) - startedOf(right)),
      ),
    },
    { kind: 'next-volume', picks: picks(nextVolumesOf(pile, read)) },
    {
      kind: 'recommended',
      picks: picks(
        pile.filter((book) => book.recommendation?.recommenderName ?? book.recommendation?.comment),
      ),
    },
    { kind: 'favorite-authors', picks: picks(byFavoriteAuthors(pile, books)) },
    { kind: 'favorite-narrators', picks: picks(byFavoriteNarrators(pile, heartedNarrators)) },
    { kind: 'awarded', picks: awardedOf(pile, works) },
    { kind: 'new-authors', picks: picks(byNewAuthors(pile, read)) },
  ]
  return sections
    .map((section) => ({ ...section, picks: section.picks.slice(0, PILE_SECTION_LIMIT) }))
    .filter((section) => section.picks.length > 0)
}

/** "La suite": in each saga the reader has read a volume of, the first volume
 *  of the pile, the saga read last first. */
const nextVolumesOf = <T extends Book>(pile: readonly T[], read: readonly Book[]): T[] => {
  const lastRead = new Map<string, number>()
  for (const book of read) {
    if (!book.series) continue
    const when = (book.finishedAt ?? book.statusChangedAt ?? book.addedAt).getTime()
    lastRead.set(book.series.saga, Math.max(lastRead.get(book.series.saga) ?? 0, when))
  }
  const first = new Map<string, T>()
  for (const book of pile) {
    const saga = book.series?.saga
    if (!saga || !lastRead.has(saga) || book.series?.kind !== 'main') continue
    const held = first.get(saga)
    if (!held || (book.series.volume ?? Infinity) < (held.series?.volume ?? Infinity))
      first.set(saga, book)
  }
  return [...first.entries()]
    .sort(([left], [right]) => (lastRead.get(right) ?? 0) - (lastRead.get(left) ?? 0))
    .map(([, book]) => book)
}

/** "Auteurs préférés": the pile's books by an author the reader rated a book
 *  of four stars or more, or hearted. */
const byFavoriteAuthors = <T extends Book>(pile: readonly T[], books: readonly Book[]): T[] => {
  const favorites = new Set(
    books.filter(isFavorite).flatMap((book) => book.authors.map((name) => authorKeyOf(name))),
  )
  return pile.filter((book) => book.authors.some((name) => favorites.has(authorKeyOf(name))))
}

/** "Narrateurs préférés": the pile's recordings read by a voice the reader
 *  hearted. Not by the stars their recordings got, as authors are: a voice
 *  reads every kind of story, the ones the reader dislikes too, so a book
 *  loved says nothing of its narrator. */
const byFavoriteNarrators = <T extends Book>(
  pile: readonly T[],
  hearted: ReadonlySet<NarratorKey>,
): T[] => pile.filter((book) => book.narrators.some((name) => hearted.has(narratorKeyOf(name))))

/** "Primés": the pile's books that won one of Découvrir's awards, matched as
 *  a shelf photo is — the same title by an author who agrees — so a
 *  translation keeping the title ("Hypérion") is found, one renaming it is
 *  not. The prize shown is the latest. */
const awardedOf = <T extends Book>(
  pile: readonly T[],
  works: readonly AwardedWork[],
): PilePick<T>[] => {
  const byTitle = new Map<string, AwardedWork[]>()
  for (const work of works) {
    const key = slugify(work.title)
    byTitle.set(key, [...(byTitle.get(key) ?? []), work])
  }
  return pile.flatMap((book) => {
    const work = byTitle
      .get(slugify(book.title))
      ?.find((candidate) => sameAuthor(book.authors[0], candidate.authors[0]))
    const award = work?.mentions[0]
    return award ? [{ book, award }] : []
  })
}

/** "Nouveaux auteurs": the pile's books by authors the reader has read
 *  nothing of yet. A book naming no author is not offered. */
const byNewAuthors = <T extends Book>(pile: readonly T[], read: readonly Book[]): T[] => {
  const known = new Set(read.flatMap((book) => book.authors.map((name) => authorKeyOf(name))))
  return pile.filter(
    (book) =>
      book.authors.length > 0 && book.authors.every((name) => !known.has(authorKeyOf(name))),
  )
}

/** The formats the pill row of the pile offers: those of its books and of
 *  the books in progress, never narrowed by the format pill itself. */
export const pileFormatsOf = (books: readonly Book[], view: ShelvesView): BookFormat[] =>
  formatsOf(
    books.filter(
      (book) =>
        (book.status === 'to-read' || book.status === 'reading') &&
        inLibraryView(book, { genre: view.genre, subgenre: view.subgenre }),
    ),
  )
