import type { BookLanguage, Genre, ReadingStatus } from '~/domain/book/types'
import { GENRES } from '~/domain/book/types'
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
): Exclude<SeriesState, 'not-started'> => {
  const published = publishedVolumes(series, currentYear)
  if (published.length === 0) return 'in-progress'
  const everyPublishedRead = published.every(
    (volume) => volume.number !== undefined && readVolumeNumbers.has(volume.number),
  )
  return everyPublishedRead ? 'complete' : 'in-progress'
}

/** How far the reader is into a saga, measured on the numbered spine of
 *  published volumes — the same yardstick as the home screen's progress bars.
 *  Related works and announced volumes are left out: counting them would make a
 *  finished spine look unfinished.
 *
 *  Null when there is no spine to measure against: a catalogue whose volumes
 *  are all unnumbered or all announced says nothing about how far along one is. */
export const progressOf = (
  series: Series,
  readVolumeNumbers: ReadonlySet<number>,
  currentYear: Year,
): { readCount: number; totalCount: number } | null => {
  const spine = publishedVolumes(series, currentYear).filter(
    (volume) => volume.kind === 'main' && volume.number !== undefined,
  )
  if (spine.length === 0) return null
  const readCount = spine.filter((volume) => readVolumeNumbers.has(Number(volume.number))).length
  return { readCount, totalCount: spine.length }
}

/** The genre a saga is shelved under: the one most of its owned volumes carry.
 *  A tie goes to the genre met first, so the answer does not change when the
 *  same books are read in another order... as long as they arrive in the same
 *  order, which the library guarantees. Undefined when no volume has a genre. */
export const genreOf = (books: readonly { genre?: Genre }[]): Genre | undefined => {
  const counts = new Map<Genre, number>()
  for (const { genre } of books) if (genre) counts.set(genre, (counts.get(genre) ?? 0) + 1)
  let leading: Genre | undefined
  for (const [genre, count] of counts)
    if (leading === undefined || count > (counts.get(leading) ?? 0)) leading = genre
  return leading
}

/** Where the reader stands on a saga they follow, as the Series tab labels it.
 *
 *  A saga nothing of which has been opened is `not-started`, catalogue or not:
 *  that is a fact about the reader's own books. Past that, the catalogue decides
 *  whether published volumes remain. Without one, an owned volume still unread
 *  holds the saga open; every owned volume read says nothing, since which
 *  volumes exist is exactly what is unknown then, and null says so. */
export const followedStateOf = (
  statuses: readonly ReadingStatus[],
  catalogue: Series | null,
  readVolumeNumbers: ReadonlySet<number>,
  currentYear: Year,
): SeriesState | null => {
  if (statuses.every((status) => status === 'to-read')) return 'not-started'
  if (catalogue) return stateOf(catalogue, readVolumeNumbers, currentYear)
  return statuses.some((status) => status !== 'read') ? 'in-progress' : null
}

// What the reader is on first, then what they finished, then what they have
// not opened. A saga read as far as the shelf goes, with no catalogue to say
// whether it is over, sits with the finished ones it most resembles.
const STATE_RANK: Record<SeriesState | 'unknown', number> = {
  'in-progress': 0,
  complete: 1,
  unknown: 2,
  'not-started': 3,
}

/** The Series tab's order: sectioned by genre in the closed list's own order,
 *  sagas of no genre last; within a genre by state, and within a state the saga
 *  whose volume last changed status first — the same recency the library is
 *  ordered on. Sagas that tie keep the order they came in.
 *
 *  Done on the server rather than on the phone because the list is paginated:
 *  grouped on the client, a section would grow again every time a page lands. */
export const inTabOrder = <
  Saga extends { genre?: Genre; state: SeriesState | null; lastStatusChangeAt: Date },
>(
  sagas: readonly Saga[],
): Saga[] => {
  const genreRank = (saga: Saga) => (saga.genre ? GENRES.indexOf(saga.genre) : GENRES.length)
  return [...sagas].sort(
    (left, right) =>
      genreRank(left) - genreRank(right) ||
      STATE_RANK[left.state ?? 'unknown'] - STATE_RANK[right.state ?? 'unknown'] ||
      right.lastStatusChangeAt.getTime() - left.lastStatusChangeAt.getTime(),
  )
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
