import type { BookLanguage, CoverUrl, Genre, ReadingStatus } from '~/domain/book/types'
import { catalogueKeyOf } from '~/domain/series/primitives'
import type {
  ReleaseDate,
  Series,
  SeriesId,
  SeriesMiss,
  SeriesName,
  SeriesState,
  Volume,
  VolumeKind,
  VolumeNumber,
} from '~/domain/series/types'
import { Year } from '~/domain/shared/primitives'
import { lovedFirst, lovedRankOf } from '~/domain/shared/rating'
import { bareTitleOf } from '~/domain/shared/saga-title'
import type { AuthorName, BookTitle, StarRating, Year as YearValue } from '~/domain/shared/types'
import { optionally } from '~/utils/input'
import { slugify } from '~/utils/slug'

/** Which edition of a saga a rule is judged for, and on which day. Without a
 *  language, the earliest announcement of any edition stands in; without a
 *  day, today. `datedUpTo` is the highest volume that edition has a date for,
 *  as `editionOf` reads it off the catalogue. */
export type Edition = { language?: BookLanguage; today?: string; datedUpTo?: number }

/** The edition as the saga's catalogue knows it: how far its release watch
 *  dated it. A translation comes out in order, so a volume past that point is
 *  not out in that language yet, however long ago it came out in another. */
export const editionOf = (series: Series, edition: Edition = {}): Edition => {
  const { language } = edition
  if (!language) return edition
  const dated = series.volumes.flatMap((volume) =>
    volume.kind === 'main' && volume.number !== undefined && volume.releases?.[language]
      ? [Number(volume.number)]
      : [],
  )
  return dated.length > 0 ? { ...edition, datedUpTo: Math.max(...dated) } : edition
}

const todayOf = (edition: Edition) => edition.today ?? new Date().toISOString().slice(0, 10)

/** The last day a date can mean: a book announced for "2027" may come out on
 *  December 31st, and is not out before then. */
const lastDayOf = (date: ReleaseDate): string =>
  date.length === 10 ? date : date.length === 7 ? `${date}-31` : `${date}-12-31`

/** When the volume comes out in that edition, as the release watch found it.
 *  Without a language, the earliest date announced to the day in any. */
export const releaseOf = (volume: Volume, language?: BookLanguage): ReleaseDate | undefined => {
  if (language) return volume.releases?.[language]
  return Object.values(volume.releases ?? {})
    .filter((date): date is ReleaseDate => date !== undefined && date.length === 10)
    .sort()[0]
}

/** A volume the reader could still be waiting for. Announced volumes are kept in
 *  the catalogue on purpose: they are what a release alert will attach to.
 *
 *  The edition's own date decides when the watch found one — a volume out in
 *  English can be months away in French. A volume past the last one dated in
 *  the edition is not translated yet: another edition's date never makes it
 *  out there. Else the first date it comes out in any language; otherwise the
 *  year of first publication does. */
export const isForthcoming = (
  volume: Volume,
  currentYear: YearValue,
  edition: Edition = {},
): boolean => {
  const own = releaseOf(volume, edition.language)
  const untranslated =
    !own &&
    edition.datedUpTo !== undefined &&
    volume.number !== undefined &&
    Number(volume.number) > edition.datedUpTo
  if (untranslated) return true
  const date = own ?? earliestRelease(volume)
  if (date) {
    const today = todayOf(edition)
    return date.length === 10 ? date > today : lastDayOf(date) >= today
  }
  return volume.publishedIn !== undefined && volume.publishedIn > currentYear
}

/** The first a volume comes out anywhere, as precisely as announced: a volume
 *  not out in any language is not out in the reader's either. */
const earliestRelease = (volume: Volume): ReleaseDate | undefined =>
  Object.values(volume.releases ?? {})
    .filter((date): date is ReleaseDate => date !== undefined)
    .sort((left, right) => lastDayOf(left).localeCompare(lastDayOf(right)))[0]

/** A volume announced to the day in that edition: close and certain enough to
 *  count as part of the saga already, where a month or a year is a rumour — and
 *  another edition's day says nothing of this one's. */
const announcedToTheDay = (volume: Volume, currentYear: YearValue, edition: Edition): boolean =>
  releaseOf(volume, edition.language)?.length === 10 && isForthcoming(volume, currentYear, edition)

export const publishedVolumes = (
  series: Series,
  currentYear: YearValue,
  edition: Edition = {},
): Volume[] => {
  const known = editionOf(series, edition)
  return series.volumes.filter((volume) => !isForthcoming(volume, currentYear, known))
}

/** The volumes a saga is measured on: the numbered main volumes already out,
 *  and the ones announced to the day in the reader's edition. Related works are
 *  left out — a novella the reader skipped would make a finished spine look
 *  unfinished — and so are volumes announced for a month or a year. A volume
 *  due on a known day counts at once: a reader up to date on a saga whose next
 *  volume comes out on October 8th is waiting for it, not done. The one
 *  yardstick behind the saga's state, its ring and the dashboard's bars, so
 *  the three can never disagree. */
export const publishedSpineOf = (
  series: Series,
  currentYear: YearValue,
  edition: Edition = {},
): Volume[] => {
  const known = editionOf(series, edition)
  return series.volumes.filter(
    (volume) =>
      volume.kind === 'main' &&
      volume.number !== undefined &&
      (!isForthcoming(volume, currentYear, known) || announcedToTheDay(volume, currentYear, known)),
  )
}

/** A saga is complete once every volume of its measured spine has been read.
 *  A reader up to date on a running saga has finished it as far as the world
 *  is concerned while the next volume is only a year or a month away; once it
 *  is announced to the day, the saga is in progress again, waiting for it.
 *
 *  A saga with no published spine at all is `in-progress`, not `complete`:
 *  "complete" would read as an achievement where nothing was achieved. */
export const stateOf = (
  series: Series,
  readVolumeNumbers: ReadonlySet<number>,
  currentYear: YearValue,
  edition: Edition = {},
): Exclude<SeriesState, 'not-started'> => {
  const spine = publishedSpineOf(series, currentYear, edition)
  if (spine.length === 0) return 'in-progress'
  const everyRead = spine.every((volume) => readVolumeNumbers.has(Number(volume.number)))
  return everyRead ? 'complete' : 'in-progress'
}

/** How long the catalogue call is not asked again about a saga it found
 *  nothing on: long enough that reopening the saga is instant, short enough
 *  that a recording published since is found without the reader asking. */
const MISS_REMEMBERED_MS = 30 * 24 * 60 * 60 * 1000

/** Whether an empty answer still stands in for asking the model again. */
export const isRecentMiss = (miss: SeriesMiss | null, now: Date): boolean =>
  miss !== null && now.getTime() - miss.missedAt.getTime() < MISS_REMEMBERED_MS

/** How far the reader is into a saga, measured on its published spine — the
 *  same yardstick as its state and the home screen's progress bars.
 *
 *  Null when there is no spine to measure against: a catalogue whose volumes
 *  are all unnumbered or all announced says nothing about how far along one is. */
export const progressOf = (
  series: Series,
  readVolumeNumbers: ReadonlySet<number>,
  currentYear: YearValue,
  edition: Edition = {},
): { readCount: number; totalCount: number } | null => {
  const spine = publishedSpineOf(series, currentYear, edition)
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

/** A stored catalogue with the reader's own numbered volumes it does not list.
 *
 *  A catalogue is written once, so a volume out since — or one the model never
 *  found, as an Audible original often is — is missing from it, and a reader
 *  who files that volume by hand saw it vanish from its own saga: the strip,
 *  the saga screen and the state all walk the catalogue's spine. The volume
 *  takes its place there with the reader's title and year, as the provisional
 *  catalogue lays out theirs. Answered to this reader only, never stored: the
 *  shared catalogue holds what the world says. Related works and unnumbered
 *  volumes have no place on a spine and are left off. The catalogue itself
 *  when it already lists every owned number. */
export const withShelvedVolumes = (
  series: Series,
  owned: readonly {
    title: BookTitle
    firstPublishedIn?: YearValue
    series?: { volume?: VolumeNumber; kind: VolumeKind }
  }[],
): Series => {
  const listed = new Set(
    series.volumes.flatMap((volume) =>
      volume.kind === 'main' && volume.number !== undefined ? [Number(volume.number)] : [],
    ),
  )
  const shelved: Volume[] = []
  for (const book of owned) {
    const number = book.series?.volume
    if (book.series?.kind !== 'main' || number === undefined || listed.has(Number(number))) continue
    listed.add(Number(number))
    shelved.push({
      number,
      title: book.title,
      ...(book.firstPublishedIn !== undefined ? { publishedIn: book.firstPublishedIn } : {}),
      kind: 'main',
    })
  }
  return shelved.length === 0 ? series : { ...series, volumes: [...series.volumes, ...shelved] }
}

/** The number a volume brought to the shelf takes in its saga's catalogue,
 *  when the catalogue lists that very volume — the one main volume titled
 *  like it, in its language or in the catalogue's own — under another number.
 *
 *  A saga published in cycles prints its numbering per cycle: Sir Arthur
 *  Benton's "cycle 2, tome 2" is Le Coup de Prague, the saga's volume 5. The
 *  cover says 2, the scan wrote 2, and the book took the place of the saga's
 *  real volume 2 while its own showed as missing. A title the catalogue holds
 *  once is the better witness. One it holds twice, or the saga's own name —
 *  what a volume without a title of its own carries — tells no volume apart,
 *  and the book keeps its number. Undefined when nothing changes. */
export const numberInCatalogue = (
  catalogue: Pick<Series, 'name' | 'volumes'>,
  book: { title: BookTitle; series?: { volume?: VolumeNumber; kind: VolumeKind } },
  language?: BookLanguage,
): VolumeNumber | undefined => {
  if (book.series?.kind !== 'main') return undefined
  const slug = slugify(bareTitleOf(book.title, catalogue.name))
  if (slug === '' || slug === slugify(catalogue.name)) return undefined
  const titled = catalogue.volumes.filter((volume) =>
    [volume.title, language && volume.titles?.[language]].some(
      (title) => title && slugify(bareTitleOf(title, catalogue.name)) === slug,
    ),
  )
  const [only] = titled
  if (titled.length !== 1 || only.kind !== 'main' || only.number === undefined) return undefined
  return Number(only.number) === Number(book.series.volume) ? undefined : only.number
}

/** The catalogue each of the reader's sagas is drawn from, keyed by saga and
 *  edition language as `catalogueKeyOf` writes it: the world's when somebody
 *  has described that edition, else the one the reader's own count makes, else
 *  none. A saga held in two languages is two catalogues, since each edition
 *  lists its own volumes; a count is about the work, and lays out a spine for
 *  every edition that has no catalogue, titled from that edition's volumes.
 *
 *  What every surface that measures a saga — the saga screen, the Series tab,
 *  the dashboard — reads its catalogue through, so a declared count reaches all
 *  three at once and none of them can forget it. */
export const cataloguesOf = (
  books: readonly {
    title: BookTitle
    authors: AuthorName[]
    language?: BookLanguage
    firstPublishedIn?: YearValue
    series?: { id: SeriesId; name: SeriesName; volume?: VolumeNumber; kind: VolumeKind }
  }[],
  known: readonly Series[],
  opinions: readonly { seriesId: SeriesId; volumeCount?: VolumeNumber }[],
): Map<string, Series> => {
  const stored = new Map(
    known.map((series) => [catalogueKeyOf(series.id, series.language), series]),
  )
  const counts = new Map(
    opinions.flatMap((opinion) =>
      opinion.volumeCount === undefined ? [] : [[opinion.seriesId, opinion.volumeCount] as const],
    ),
  )
  const catalogues = new Map<string, Series>()
  for (const saga of followedSagasOf(books)) {
    const key = catalogueKeyOf(saga.id, saga.language)
    const series = stored.get(key)
    if (series) {
      catalogues.set(key, withShelvedVolumes(series, saga.books))
      continue
    }
    const count = counts.get(saga.id)
    if (count === undefined) continue
    catalogues.set(key, {
      ...provisionalCatalogueOf(
        // A saga no owned volume names an author for is catalogued under none:
        // the count still deserves its spine.
        { id: saga.id, name: saga.name, author: saga.author ?? ('' as AuthorName) },
        saga.books,
        count,
      ),
      ...(saga.language ? { language: saga.language } : {}),
    })
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
  currentYear: YearValue,
  unfollowed = false,
  edition: Edition = {},
): SeriesState | null => {
  // The reader's own choice, above whatever their volumes say: a saga set
  // aside is neither in progress nor done.
  if (unfollowed) return 'unfollowed'
  if (statuses.every((status) => status === 'to-read')) return 'not-started'
  if (catalogue) return stateOf(catalogue, readVolumeNumbers, currentYear, edition)
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

/** The Series tab's favourites: the sagas the reader judged, hearts first,
 *  then five stars down to one, each rank the saga shelved last first. A saga
 *  borrows nothing from its volumes: its stars are a judgement of the whole. */
export const inLovedOrder = <
  Saga extends { shelvedAt: Date; opinion: { favorite?: boolean; rating?: StarRating } | null },
>(
  sagas: readonly Saga[],
): Saga[] =>
  lovedFirst(
    sagas,
    (saga) => lovedRankOf({ favorite: saga.opinion?.favorite, rating: saga.opinion?.rating }),
    (left, right) => right.shelvedAt.getTime() - left.shelvedAt.getTime(),
  )

/** The sagas a filter of the Series tab keeps: the hearted ones, and those in
 *  one state. A saga whose state is unknown — every owned volume read and no
 *  catalogue to say more — is kept with the complete ones it resembles.
 *
 *  A saga set aside is kept by every list that does not name a state — the
 *  list by date is the whole shelf, as the Library tab keeps its dropped
 *  books — and has a filter of its own. */
export const matchingFilter = <Saga extends { state: SeriesState | null; favorite: boolean }>(
  sagas: readonly Saga[],
  filter: { favorite?: boolean; state?: SeriesState },
): Saga[] =>
  sagas.filter((saga) => {
    const state = saga.state ?? 'complete'
    if (filter.favorite && !saga.favorite) return false
    if (filter.state === undefined) return true
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
 *  those are two sets of books. A book is written French when nothing names
 *  its edition; a record that still carries no language is its own group and
 *  sorts last. */
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

/** One volume of a saga as the release watch found it in one language. */
export type FoundVolume = {
  volume: VolumeNumber
  title: BookTitle
  date?: ReleaseDate
  coverUrl?: CoverUrl
}

/** Where a volume the release watch found goes in the catalogue: the index of
 *  the volume it is, `'new'` for one the spine lacks, or undefined for one that
 *  has no place on it.
 *
 *  The watch numbers a saga as the web it searched does, and the web does not
 *  always agree with the catalogue: Foundation in reading order puts its two
 *  prequels first, so its "volume 6" is the catalogue's volume 4. Matched on
 *  the number alone, every volume took its neighbour's title and date, and the
 *  last two joined the spine a second time. A title is the better witness, so
 *  it decides whenever it names one volume on both sides; the number decides
 *  only otherwise — a translated title, or volumes that all carry the saga's
 *  name — and never hands over a volume another entry found by its title. */
const placeOf = (
  volumes: readonly Volume[],
  found: readonly FoundVolume[],
  entry: FoundVolume,
): number | 'new' | undefined => {
  const counted = (titles: readonly string[]) => {
    const counts = new Map<string, number>()
    for (const title of titles) counts.set(slugify(title), (counts.get(slugify(title)) ?? 0) + 1)
    return counts
  }
  const held = counted(volumes.map((volume) => volume.title))
  const named = counted(found.map((other) => other.title))
  const distinctive = (title: string) =>
    held.get(slugify(title)) === 1 && named.get(slugify(title)) === 1
  if (distinctive(entry.title)) {
    const index = volumes.findIndex((volume) => slugify(volume.title) === slugify(entry.title))
    const volume = volumes[index]
    return volume?.kind === 'main' && volume.number !== undefined ? index : undefined
  }
  const index = volumes.findIndex(
    (volume) => volume.kind === 'main' && volume.number === entry.volume,
  )
  if (index === -1) return 'new'
  const volume = volumes[index]
  return volume && distinctive(volume.title) ? undefined : index
}

/** The catalogue with what the release watch found of one edition written in:
 *  each volume's date, title and cover in that language, and any numbered
 *  volume the catalogue lacked — an announced volume 5 — appended to the spine.
 *  A found volume is placed by its title before its number (`placeOf`).
 *  Nothing is ever removed: a search that misses a volume does not unmake it.
 *  The same catalogue, by reference, when nothing changed, so the caller can
 *  skip the write. */
export const withReleases = (
  series: Series,
  language: BookLanguage,
  listed: readonly FoundVolume[],
): Series => {
  const found = listed.map((entry) => ({ ...entry, title: bareTitleOf(entry.title, series.name) }))
  let changed = false
  const matches = new Map<number, FoundVolume>()
  const unlisted: FoundVolume[] = []
  for (const entry of found) {
    const place = placeOf(series.volumes, found, entry)
    if (place === 'new') unlisted.push(entry)
    else if (place !== undefined && !matches.has(place)) matches.set(place, entry)
  }
  const volumes = series.volumes.map((volume, index) => {
    const match = matches.get(index)
    if (!match) return volume
    const next = { ...volume }
    if (match.date && volume.releases?.[language] !== match.date) {
      next.releases = { ...volume.releases, [language]: match.date }
      changed = true
    }
    if (
      slugify(match.title) !== slugify(volume.title) &&
      volume.titles?.[language] !== match.title
    ) {
      next.titles = { ...volume.titles, [language]: match.title }
      changed = true
    }
    if (match.coverUrl && volume.covers?.[language] !== match.coverUrl) {
      next.covers = { ...volume.covers, [language]: match.coverUrl }
      changed = true
    }
    return next
  })
  const known = new Set(
    volumes.flatMap((volume) => (volume.kind === 'main' ? [volume.number] : [])),
  )
  for (const entry of unlisted) {
    if (known.has(entry.volume)) continue
    known.add(entry.volume)
    changed = true
    volumes.push({
      number: entry.volume,
      title: entry.title,
      kind: 'main',
      // A store's placeholder date (2099-12-31) is past any publication year:
      // the volume still joins, with its date, but without a year.
      publishedIn: entry.date ? optionally(Number(entry.date.slice(0, 4)), Year) : undefined,
      releases: entry.date ? { [language]: entry.date } : undefined,
      covers: entry.coverUrl ? { [language]: entry.coverUrl } : undefined,
    })
  }
  if (!changed) return series
  return { ...series, volumes: inCatalogueOrder(volumes) }
}

/** The catalogue with every volume titled without its saga (`titleWithoutSaga`):
 *  the screens show the saga and the number beside the title. */
export const withBareTitles = (series: Series): Series => ({
  ...series,
  volumes: series.volumes.map((volume) => ({
    ...volume,
    title: bareTitleOf(volume.title, series.name),
    ...(volume.titles
      ? {
          titles: Object.fromEntries(
            Object.entries(volume.titles).map(([language, title]) => [
              language,
              bareTitleOf(title, series.name),
            ]),
          ),
        }
      : {}),
  })),
})

/** A catalogue built again keeps what the release watch wrote on it: the
 *  model's fresh list knows nothing of release dates. It lists only the
 *  volumes already out in its edition, so a volume the watch found announced
 *  is kept too, or a refresh would undo the watch until its next pass. A volume the watch never dated is the
 *  old catalogue's alone, and goes with it. */
export const keepingReleases = (fresh: Series, previous: Series | null): Series => {
  if (!previous) return fresh
  const sameVolume = (left: Volume, right: Volume) =>
    left.kind === right.kind &&
    (left.number !== undefined ? left.number === right.number : left.title === right.title)
  const volumes = fresh.volumes.map((volume) => {
    const before = previous.volumes.find((entry) => sameVolume(entry, volume))
    if (!before) return volume
    return {
      ...volume,
      releases: before.releases ?? volume.releases,
      titles: before.titles ?? volume.titles,
      covers: before.covers ?? volume.covers,
    }
  })
  const watched = previous.volumes.filter(
    (volume) =>
      volume.releases !== undefined && !fresh.volumes.some((entry) => sameVolume(entry, volume)),
  )
  return watched.length === 0
    ? { ...fresh, volumes }
    : { ...fresh, volumes: inCatalogueOrder([...volumes, ...watched]) }
}
