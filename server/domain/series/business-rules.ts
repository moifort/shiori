import type { BookLanguage } from '~/domain/book/types'
import type {
  Series,
  SeriesId,
  SeriesName,
  SeriesState,
  Volume,
  VolumeKind,
} from '~/domain/series/types'
import type { AuthorName, Year } from '~/domain/shared/types'

/** A volume the reader could still be waiting for. Announced volumes are kept in
 *  the catalogue on purpose: they are what a release alert will attach to. */
export const isForthcoming = (volume: Volume, currentYear: Year): boolean =>
  volume.publishedIn !== undefined && volume.publishedIn > currentYear

export const publishedVolumes = (series: Series, currentYear: Year): Volume[] =>
  series.volumes.filter((volume) => !isForthcoming(volume, currentYear))

/** A saga is complete once every volume that exists has been read. Forthcoming
 *  volumes are excluded: a reader who is up to date on a running saga has
 *  finished it as far as the world is concerned, and telling them otherwise
 *  because book 15 is announced for next year would be wrong.
 *
 *  A saga with no published volume at all is `in-progress`, not `complete`:
 *  "complete" would read as an achievement where nothing was achieved. */
export const stateOf = (
  series: Series,
  readVolumeNumbers: ReadonlySet<number>,
  currentYear: Year,
): SeriesState => {
  const published = publishedVolumes(series, currentYear)
  if (published.length === 0) return 'in-progress'
  const everyPublishedRead = published.every(
    (volume) => volume.number !== undefined && readVolumeNumbers.has(volume.number),
  )
  return everyPublishedRead ? 'complete' : 'in-progress'
}

/** Catalogue order for a whole saga. */
export const inCatalogueOrder = (volumes: readonly Volume[]): Volume[] =>
  [...volumes].sort(compareVolumes)

const KIND_RANK: Record<VolumeKind, number> = {
  main: 0,
  prequel: 1,
  'spin-off': 2,
  novella: 3,
  companion: 4,
}

/** The one ordering rule for anything that sits in a saga: the numbered spine
 *  first, ascending, then what orbits it. Shared with the library so a series
 *  section and the series screen never disagree on order — they are the same
 *  saga seen twice.
 *
 *  Titles break the tie between two unnumbered entries. A stable order matters
 *  more than a clever one here: both surfaces are read top to bottom. */
export const compareWithinSeries = (
  left: { kind: VolumeKind; number?: number; title: string },
  right: { kind: VolumeKind; number?: number; title: string },
): number => {
  const byKind = KIND_RANK[left.kind] - KIND_RANK[right.kind]
  if (byKind !== 0) return byKind
  if (left.number !== undefined && right.number !== undefined) return left.number - right.number
  if (left.number !== undefined) return -1
  if (right.number !== undefined) return 1
  return left.title.localeCompare(right.title)
}

const compareVolumes = (left: Volume, right: Volume): number => compareWithinSeries(left, right)

/** Main volumes and everything else, which is how the series screen lays them out:
 *  the spine in order, then a "Related works" block underneath. */
export const splitBySpine = (series: Series): { spine: Volume[]; relatedWorks: Volume[] } => {
  const ordered = inCatalogueOrder(series.volumes)
  return {
    spine: ordered.filter((volume) => volume.kind === 'main'),
    relatedWorks: ordered.filter((volume) => volume.kind !== 'main'),
  }
}

/** A saga the reader owns volumes of, taken from the books themselves.
 *
 *  Generic over the book so the caller keeps whatever it passed in: the state of
 *  a saga is read off the very records that named it, and re-fetching them to
 *  count would be a second pass over a list already in hand. */
export type FollowedSaga<Book> = {
  id: SeriesId
  name: SeriesName
  /** The first author of a volume the reader owns. The catalogue carries an
   *  author of its own; this one is what answers for a saga that has none. */
  author?: AuthorName
  /** The language these volumes are in. A saga held in two languages answers
   *  twice, once per language, because that is how the library shelves it. */
  language?: BookLanguage
  books: Book[]
}

/** Which sagas a library follows, in alphabetical order.
 *
 *  Read off the denormalized membership rather than off the catalogue, which is
 *  the whole point of denormalizing it: an Audible import and a book added by
 *  hand both name their saga and neither calls the model, so a catalogue-first
 *  reading lost every saga those two ever produced.
 *
 *  A saga the catalogue has never heard of is still a saga the reader is
 *  reading. What is missing then is the list of volumes that exist, not the
 *  saga.
 *
 *  Keyed by language as well as by saga, the same way the library shelves are:
 *  a reader who holds Dune in French and in English follows two rows, because
 *  those are two sets of books. An unrecorded language is its own group and
 *  sorts last — unknown is not French. */
export const followedSagasOf = <
  Book extends {
    series?: { id: SeriesId; name: SeriesName }
    authors: AuthorName[]
    language?: BookLanguage
  },
>(
  books: readonly Book[],
): FollowedSaga<Book>[] => {
  const sagas = new Map<string, FollowedSaga<Book>>()
  for (const book of books) {
    const membership = book.series
    if (!membership) continue
    const key = `${membership.id}\u0000${book.language ?? ''}`
    const known = sagas.get(key)
    if (known) {
      known.books.push(book)
      known.author ??= book.authors[0]
    } else
      sagas.set(key, {
        id: membership.id,
        name: membership.name,
        author: book.authors[0],
        language: book.language,
        books: [book],
      })
  }
  return [...sagas.values()].sort((left, right) => {
    const byName = left.name.localeCompare(right.name)
    return byName !== 0
      ? byName
      : (left.language ?? '\uffff').localeCompare(right.language ?? '\uffff')
  })
}
