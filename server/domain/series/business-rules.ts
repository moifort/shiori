import type { BookLanguage, Genre, ReadingStatus } from '~/domain/book/types'
import type {
  Series,
  SeriesId,
  SeriesName,
  SeriesState,
  Volume,
  VolumeKind,
  VolumeNumber,
} from '~/domain/series/types'
import type { AuthorName, BookTitle, Year } from '~/domain/shared/types'
import { slugify } from '~/utils/slug'

/** A volume the reader could still be waiting for. Announced volumes are kept in
 *  the catalogue on purpose: they are what a release alert will attach to. */
export const isForthcoming = (volume: Volume, currentYear: Year): boolean =>
  volume.publishedIn !== undefined && volume.publishedIn > currentYear

export const publishedVolumes = (series: Series, currentYear: Year): Volume[] =>
  series.volumes.filter((volume) => !isForthcoming(volume, currentYear))

/** The volumes a saga is measured on: the numbered main volumes already out.
 *  Related works and announced volumes are left out — a novella the reader
 *  skipped, or book 15 due next year, would make a finished spine look
 *  unfinished. The one yardstick behind the saga's state, its ring and the
 *  dashboard's bars, so the three can never disagree. */
export const publishedSpineOf = (series: Series, currentYear: Year): Volume[] =>
  publishedVolumes(series, currentYear).filter(
    (volume) => volume.kind === 'main' && volume.number !== undefined,
  )

/** A saga is complete once every volume of its published spine has been read.
 *  A reader who is up to date on a running saga has finished it as far as the
 *  world is concerned, and telling them otherwise because book 15 is announced
 *  for next year, or because a side novella is unread, would be wrong.
 *
 *  A saga with no published spine at all is `in-progress`, not `complete`:
 *  "complete" would read as an achievement where nothing was achieved. */
export const stateOf = (
  series: Series,
  readVolumeNumbers: ReadonlySet<number>,
  currentYear: Year,
): Exclude<SeriesState, 'not-started'> => {
  const spine = publishedSpineOf(series, currentYear)
  if (spine.length === 0) return 'in-progress'
  const everyRead = spine.every((volume) => readVolumeNumbers.has(Number(volume.number)))
  return everyRead ? 'complete' : 'in-progress'
}

/** How far the reader is into a saga, measured on its published spine — the
 *  same yardstick as its state and the home screen's progress bars.
 *
 *  Null when there is no spine to measure against: a catalogue whose volumes
 *  are all unnumbered or all announced says nothing about how far along one is. */
export const progressOf = (
  series: Series,
  readVolumeNumbers: ReadonlySet<number>,
  currentYear: Year,
): { readCount: number; totalCount: number } | null => {
  const spine = publishedSpineOf(series, currentYear)
  if (spine.length === 0) return null
  const readCount = spine.filter((volume) => readVolumeNumbers.has(Number(volume.number))).length
  return { readCount, totalCount: spine.length }
}

/** A catalogue drawn from what the reader knows, for a saga nobody has
 *  described: the number of volumes they declared, laid out as a numbered spine
 *  with their own volumes at their numbers and the saga's name standing in for
 *  every volume they lack. Marked provisional, and never stored.
 *
 *  The spine runs at least as far as the highest volume on the shelf: a count
 *  below it would make that volume vanish from its own saga. Unnumbered owned
 *  volumes are left off, as an unnumbered entry has no place on a spine. */
export const provisionalCatalogueOf = (
  saga: { id: SeriesId; name: SeriesName; author: AuthorName },
  owned: readonly { title: BookTitle; series?: { volume?: VolumeNumber; kind: VolumeKind } }[],
  volumeCount: VolumeNumber,
  now = new Date(),
): Series => {
  // The first title seen stands for a number held twice — two editions of one
  // volume — so the spine does not depend on the order the books came in.
  const titles = new Map<number, BookTitle>()
  for (const book of owned)
    if (book.series?.kind === 'main' && book.series.volume !== undefined)
      if (!titles.has(book.series.volume)) titles.set(book.series.volume, book.title)
  const length = Math.max(Number(volumeCount), ...titles.keys())
  return {
    id: saga.id,
    name: saga.name,
    author: saga.author,
    volumes: Array.from({ length }, (_, index) => {
      const number = (index + 1) as VolumeNumber
      return {
        number,
        title: titles.get(number) ?? (saga.name as string as BookTitle),
        kind: 'main',
      }
    }),
    catalogedAt: now,
    provisional: true,
  }
}

/** The catalogue each of the reader's sagas is drawn from, keyed by saga: the
 *  world's when somebody has described it, else the one the reader's own count
 *  makes, else none. One entry per saga whatever the number of languages it is
 *  held in — a count is about the work, not an edition, and the provisional
 *  spine takes its titles from whichever volumes the reader holds.
 *
 *  What every surface that measures a saga — the saga screen, the Series tab,
 *  the dashboard — reads its catalogue through, so a declared count reaches all
 *  three at once and none of them can forget it. */
export const cataloguesOf = (
  books: readonly {
    title: BookTitle
    authors: AuthorName[]
    language?: BookLanguage
    series?: { id: SeriesId; name: SeriesName; volume?: VolumeNumber; kind: VolumeKind }
  }[],
  known: readonly Series[],
  opinions: readonly { seriesId: SeriesId; volumeCount?: VolumeNumber }[],
): Map<SeriesId, Series> => {
  const stored = new Map(known.map((series) => [series.id, series]))
  const counts = new Map(
    opinions.flatMap((opinion) =>
      opinion.volumeCount === undefined ? [] : [[opinion.seriesId, opinion.volumeCount] as const],
    ),
  )
  const catalogues = new Map<SeriesId, Series>()
  // One row per saga and language: the second edition of a saga is skipped,
  // since its spine was drawn from every edition's volumes on the first.
  for (const saga of followedSagasOf(books)) {
    if (catalogues.has(saga.id)) continue
    const series = stored.get(saga.id)
    if (series) {
      catalogues.set(saga.id, series)
      continue
    }
    const count = counts.get(saga.id)
    if (count === undefined) continue
    catalogues.set(
      saga.id,
      provisionalCatalogueOf(
        // A saga no owned volume names an author for is catalogued under none:
        // the count still deserves its spine.
        { id: saga.id, name: saga.name, author: saga.author ?? ('' as AuthorName) },
        books.filter((book) => book.series?.id === saga.id),
        count,
      ),
    )
  }
  return catalogues
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
 *  A saga the reader stopped following is `unfollowed`, whatever else holds.
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
  unfollowed = false,
): SeriesState | null => {
  // The reader's own choice, above whatever their volumes say: a saga set
  // aside is neither in progress nor done.
  if (unfollowed) return 'unfollowed'
  if (statuses.every((status) => status === 'to-read')) return 'not-started'
  if (catalogue) return stateOf(catalogue, readVolumeNumbers, currentYear)
  // A dropped volume is as done with as a read one: it holds nothing open.
  return statuses.some((status) => status !== 'read' && status !== 'dropped') ? 'in-progress' : null
}

/** The Series tab's order: the saga whose latest volume was shelved most
 *  recently first — finished, else started, else added, the date the Library
 *  tab orders books on — so the app cuts it into the same month sections.
 *  Sagas that tie keep the order they came in.
 *
 *  Done on the server rather than on the phone because the list is paginated:
 *  ordered on the client, a page landing late would reshuffle what is drawn. */
export const inTabOrder = <Saga extends { shelvedAt: Date }>(sagas: readonly Saga[]): Saga[] =>
  [...sagas].sort((left, right) => right.shelvedAt.getTime() - left.shelvedAt.getTime())

/** The sagas a filter of the Series tab keeps: the hearted ones, and those in
 *  one state. A saga whose state is unknown — every owned volume read and no
 *  catalogue to say more — is kept with the complete ones it resembles.
 *
 *  A saga set aside shows only under its own filter: the reader put it out of
 *  their way, and every other list — everything, the favourites — leaves it
 *  out. */
export const matchingFilter = <Saga extends { state: SeriesState | null; favorite: boolean }>(
  sagas: readonly Saga[],
  filter: { favorite?: boolean; state?: SeriesState },
): Saga[] =>
  sagas.filter((saga) => {
    const state = saga.state ?? 'complete'
    if (filter.favorite && !saga.favorite) return false
    if (filter.state === undefined) return state !== 'unfollowed'
    return state === filter.state
  })

/** A catalogue with every volume once. The grounded model can answer one entry
 *  per edition it found — Blood Song listed Tome 1 and Tome 2 twice each — so
 *  the list is folded before it is stored: one main volume per number, and one
 *  entry per kind and title for everything off the numbering. The first entry
 *  seen is kept, in the order the model gave them. */
export const withoutDuplicateVolumes = (volumes: readonly Volume[]): Volume[] => {
  const seen = new Set<string>()
  return volumes.filter((volume) => {
    const key =
      volume.kind === 'main' && volume.number !== undefined
        ? `main#${volume.number}`
        : `${volume.kind}:${slugify(volume.title)}`
    if (seen.has(key)) return false
    seen.add(key)
    return true
  })
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
