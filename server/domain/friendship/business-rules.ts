import type { Book, Genre, TaggedSubgenre } from '~/domain/book/types'
import type { SeriesId } from '~/domain/series/types'

/** When the reader last did anything with a book: picked it up, moved its
 *  status, or had a sync move its listening position. What "most recently
 *  active first" orders on, falling back through the older stamps for records
 *  written before the newer ones existed. */
export const lastActivityOf = (
  book: Pick<Book, 'addedAt' | 'updatedAt' | 'statusChangedAt' | 'startedAt'>,
): Date =>
  new Date(
    Math.max(
      book.addedAt.getTime(),
      book.updatedAt?.getTime() ?? 0,
      book.statusChangedAt?.getTime() ?? 0,
      book.startedAt?.getTime() ?? 0,
    ),
  )

/** The hearted books that are not already shown through a hearted saga.
 *
 *  A favourite saga stands for its volumes: listing one of them again among the
 *  favourite books would say the same thing twice, and a list shared with
 *  somebody else would carry the volume twice. */
export const favoritesOutsideSagas = <Favorite extends Pick<Book, 'series'>>(
  favorites: readonly Favorite[],
  favoriteSagaIds: ReadonlySet<SeriesId>,
): Favorite[] => favorites.filter((book) => !book.series || !favoriteSagaIds.has(book.series.id))

/** The subgenre a saga is described by: the leading subgenre of the first
 *  volume that carries the saga's genre, so the pair reads as one description
 *  rather than two facts taken from different books. */
export const subgenreOf = (
  books: readonly { genre?: Genre; subgenres: readonly TaggedSubgenre[] }[],
  genre: Genre | undefined,
): TaggedSubgenre | undefined =>
  books.find((book) => book.genre === genre && book.subgenres.length > 0)?.subgenres[0]

/** A saga's volumes on the shelf in reading order: main volumes by number,
 *  then the rest — prequels, novellas, spin-offs — by number, an unnumbered
 *  volume last in its group. */
export const inReadingOrder = <Volume extends Pick<Book, 'series'>>(
  volumes: readonly Volume[],
): Volume[] =>
  [...volumes].sort(
    (left, right) =>
      Number(left.series?.kind !== 'main') - Number(right.series?.kind !== 'main') ||
      (left.series?.volume ?? Number.POSITIVE_INFINITY) -
        (right.series?.volume ?? Number.POSITIVE_INFINITY),
  )
