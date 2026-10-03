import { mainLanguageOf } from '~/domain/author/business-rules'
import { authorKeyOf } from '~/domain/author/primitives'
import type { AuthorKey, ShelvedAuthor } from '~/domain/author/types'
import type { Book, BookFormat, BookLanguage } from '~/domain/book/types'
import type { ScanResult } from '~/domain/scan/types'
import {
  type FoundVolume as CatalogueVolume,
  editionOf,
  isForthcoming,
  withReleases,
} from '~/domain/series/business-rules'
import { isAudioSeries } from '~/domain/series/primitives'
import type { Series, SeriesId, VolumeNumber } from '~/domain/series/types'
import type { FollowedSeries } from '~/domain/series/use-case'
import { type Language, SUPPORTED_LANGUAGES } from '~/domain/shared/language'
import { Year } from '~/domain/shared/primitives'
import { slugify } from '~/utils/slug'
import type {
  AnnouncedVolumePreview,
  AudibleRecording,
  AuthorWatch,
  DiscoveryReader,
  FoundVolume,
  FoundWork,
  ReleaseDate,
  ReleaseFormat,
  SagaReleases,
  SagaWatch,
  WatchedAuthor,
  WatchedSaga,
} from './types'

/** How often the web is searched again for one saga: a publisher announces a
 *  volume months ahead, and the grounded call is the expensive part — every
 *  search it runs is billed, about a cent each. Weekly, these looks were the
 *  one Gemini cost that came back every month without anybody scanning; two
 *  weeks halves it and still catches an announcement long before the day. */
export const WATCH_EVERY_MS = 14 * 86_400_000
/** How often the web is searched again for one author. An author publishes a
 *  few times a year and their shelf keeps three months of works out, so a
 *  month apart misses nothing a reader would see. */
export const AUTHOR_WATCH_EVERY_MS = 30 * 86_400_000
/** How often the hourly pass reads a reader's library again to learn which
 *  sagas they follow. Opening the tab does it at once. */
export const SYNC_EVERY_MS = 86_400_000
/** How long a volume out stays among the new releases: two weeks, as often
 *  as a saga is looked up again, so one only learned of once out still shows. */
const RECENT_DAYS = 14
/** How late an alert may still go out for a volume the morning pass missed. */
const ALERT_GRACE_DAYS = 14

export const todayOf = (now: Date) => now.toISOString().slice(0, 10)

const dayMinus = (today: string, days: number): string => {
  const [year, month, day] = today.split('-').map(Number)
  return new Date(Date.UTC(year, month - 1, day) - days * 86_400_000).toISOString().slice(0, 10)
}

// MARK: - What is watched

export const watchKeyOf = ({ seriesId, language }: Pick<WatchedSaga, 'seriesId' | 'language'>) =>
  `${seriesId}--${language}`

/** The format a saga is made of: its recordings for the saga heard, its
 *  printed books for the saga read. */
export const formatOf = (seriesId: SeriesId): ReleaseFormat =>
  isAudioSeries(seriesId) ? 'audiobook' : 'book'

/** Whether Discover looks out for a saga's next volumes: not when the reader
 *  set it aside, nor when they gave up on one of its volumes — a volume dropped
 *  says the saga lost them. A saga of books that record no language cannot be
 *  searched for. */
export const isDiscoverable = <Saga extends Pick<FollowedSeries, 'language' | 'state' | 'books'>>(
  saga: Saga,
): saga is Saga & { language: BookLanguage } =>
  saga.language !== undefined &&
  saga.state !== 'unfollowed' &&
  !saga.books.some((book) => book.status === 'dropped')

/** Every saga the reader follows, in the language they hold it in: all of
 *  them Discover looks out for. */
export const watchedSagasOf = (followed: readonly FollowedSeries[]): WatchedSaga[] => {
  const sagas = new Map<string, WatchedSaga>()
  for (const saga of followed) {
    if (!isDiscoverable(saga)) continue
    const language = saga.language
    const asin = isAudioSeries(saga.id)
      ? saga.books.find((book) => book.audibleAsin && book.language === language)?.audibleAsin
      : undefined
    const furthest = furthestHeldOf(saga.books, language)
    const watched: WatchedSaga = {
      seriesId: saga.id,
      language,
      name: saga.name,
      ...(saga.author ? { author: saga.author } : {}),
      ...(asin ? { asin } : {}),
      ...(furthest ? { furthest } : {}),
    }
    sagas.set(watchKeyOf(watched), watched)
  }
  return [...sagas.values()]
}

/** The furthest numbered volume of a saga the reader holds in that language,
 *  and when they added it — a novella or a companion is numbered apart from
 *  the volumes a watch lists. */
const furthestHeldOf = (
  books: readonly Pick<Book, 'series' | 'language' | 'addedAt'>[],
  language: BookLanguage,
): WatchedSaga['furthest'] => {
  let furthest: WatchedSaga['furthest']
  for (const book of books) {
    const number = book.series?.kind === 'main' ? book.series.volume : undefined
    if (number === undefined || book.language !== language) continue
    if (!furthest || number > furthest.number) furthest = { number, addedAt: book.addedAt }
  }
  return furthest
}

/** Whether a saga is due for another look on the web. */
export const watchIsStale = (watch: SagaWatch | undefined, now: Date): boolean =>
  !watch || now.getTime() - watch.checkedAt.getTime() > WATCH_EVERY_MS

/** Whether the hourly pass must read this reader's library again. */
export const readerIsStale = (reader: DiscoveryReader | undefined, now: Date): boolean =>
  !reader || now.getTime() - reader.syncedAt.getTime() > SYNC_EVERY_MS

/** Whether a reader added a volume of the saga since its last look that the
 *  look did not find: the web is searched again rather than in two weeks. Once
 *  looked up again, the watch is newer than the volume, so a volume the web
 *  still does not know costs one look, not one an hour. */
export const watchIsBehind = (watch: SagaWatch | undefined, saga: WatchedSaga): boolean => {
  const { furthest } = saga
  if (!watch || !furthest || furthest.addedAt <= watch.checkedAt) return false
  return !watch.volumes.some((volume) => volume.number === furthest.number)
}

/** The sagas every reader follows, each once, the ones never looked up first,
 *  then the longest unchecked: every one two weeks old, and every one a reader
 *  holds further than it found. */
export const dueWatches = (
  readers: readonly DiscoveryReader[],
  watches: ReadonlyMap<string, SagaWatch>,
  now: Date,
): WatchedSaga[] => {
  const sagas = new Map<string, WatchedSaga>()
  const behind = new Set<string>()
  for (const reader of readers)
    for (const saga of reader.sagas) {
      const key = watchKeyOf(saga)
      sagas.set(key, saga)
      if (watchIsBehind(watches.get(key), saga)) behind.add(key)
    }
  const checkedAt = (saga: WatchedSaga) => watches.get(watchKeyOf(saga))?.checkedAt.getTime() ?? 0
  return [...sagas.values()]
    .filter((saga) => {
      const key = watchKeyOf(saga)
      return behind.has(key) || watchIsStale(watches.get(key), now)
    })
    .sort((left, right) => checkedAt(left) - checkedAt(right))
}

// MARK: - The authors watched

export const authorWatchKeyOf = ({
  authorKey,
  format,
  language,
}: Pick<WatchedAuthor, 'authorKey' | 'format' | 'language'>) =>
  `${authorKey}--${format}--${language}`

/** The way a book reaches the reader, as Découvrir sorts them: heard, or read
 *  on paper or on a screen. */
export const releaseFormatOf = (format: BookFormat | undefined): ReleaseFormat =>
  format === 'audiobook' ? 'audiobook' : 'book'

type HeldBook = Pick<Book, 'format' | 'language' | 'status'>

/** Every author the reader holds, in each format they hold them in and the
 *  language most of those books are in: an author only heard is watched among
 *  the recordings, one only read among the books, one both in both. Not an
 *  author whose every book the reader gave up on, nor a format whose books
 *  record no language — it cannot be searched for. */
export const watchedAuthorsOf = (
  authors: readonly Pick<ShelvedAuthor<HeldBook>, 'key' | 'name' | 'books'>[],
): WatchedAuthor[] =>
  authors.flatMap((author) => {
    if (author.books.every((book) => book.status === 'dropped')) return []
    return (['book', 'audiobook'] as const).flatMap((format): WatchedAuthor[] => {
      const language = mainLanguageOf(
        author.books.filter((book) => releaseFormatOf(book.format) === format),
      )
      return language ? [{ authorKey: author.key, name: author.name, format, language }] : []
    })
  })

/** Whether an author is due for another look on the web. */
export const authorWatchIsStale = (watch: AuthorWatch | undefined, now: Date): boolean =>
  !watch || now.getTime() - watch.checkedAt.getTime() > AUTHOR_WATCH_EVERY_MS

/** The authors every reader holds, each once, the ones never looked up first,
 *  then the longest unchecked. */
export const dueAuthorWatches = (
  readers: readonly DiscoveryReader[],
  watches: ReadonlyMap<string, AuthorWatch>,
  now: Date,
): WatchedAuthor[] => {
  const authors = new Map<string, WatchedAuthor>()
  for (const reader of readers)
    for (const author of reader.authors ?? []) authors.set(authorWatchKeyOf(author), author)
  const checkedAt = (author: WatchedAuthor) =>
    watches.get(authorWatchKeyOf(author))?.checkedAt.getTime() ?? 0
  return [...authors.values()]
    .filter((author) => authorWatchIsStale(watches.get(authorWatchKeyOf(author)), now))
    .sort((left, right) => checkedAt(left) - checkedAt(right))
}

/** The language a reader is written to in, until they open the tab and their
 *  request says: the app's language they read most sagas in, else English. */
export const likelyLanguageOf = (sagas: readonly WatchedSaga[]): Language => {
  const count = (language: Language) => sagas.filter((saga) => saga.language === language).length
  return [...SUPPORTED_LANGUAGES].sort(
    (left, right) => count(right) - count(left) || (left === 'en' ? -1 : 1),
  )[0]
}

// MARK: - The catalogue

/** What a watch writes into the saga's shared catalogue: every volume found,
 *  with its date, title and cover in that language, so the Series tab, the
 *  saga screen and the dashboard say when the next one comes out. */
export const catalogueVolumesOf = (watch: SagaWatch): CatalogueVolume[] =>
  watch.volumes.map((volume) => ({
    volume: volume.number,
    title: volume.title,
    date: volume.date,
    coverUrl: volume.coverUrl,
  }))

// MARK: - Dates

/** The last day a date can mean: a book announced for "2027" may come out on
 *  December 31st, and is not out before then. */
export const lastDayOf = (date: ReleaseDate): string =>
  date.length === 10 ? date : date.length === 7 ? `${date}-31` : `${date}-12-31`

/** Whether a volume is still to come: a day after today, or a month or a year
 *  not over yet. A volume with no date was found out already. */
export const isUpcoming = (date: ReleaseDate | undefined, today: string): boolean =>
  date !== undefined && (date.length === 10 ? date > today : lastDayOf(date) >= today)

// MARK: - What the reader sees

/** The numbered volumes the reader holds of the saga, in its language. */
const heldNumbersOf = (books: readonly Pick<Book, 'series'>[]): Set<number> =>
  new Set(
    books.flatMap((book) =>
      book.series?.volume !== undefined && book.series.kind === 'main' ? [book.series.volume] : [],
    ),
  )

/** A volume of the saga in the watch's language, and whether it is still to
 *  come. */
type Candidate = { volume: FoundVolume; upcoming: boolean }

/** Every numbered volume of the saga, as the Series tab lays it out: the
 *  catalogue's spine — whose volumes the watch appends to — with what the watch
 *  found of each laid over it, and any volume the watch found that the
 *  catalogue does not hold yet. A volume in the catalogue is out or not by the
 *  catalogue's rule, the one its strip is drawn by, so the two tabs count the
 *  same volumes; a volume only the watch knows, by the watch's date. */
const candidatesOf = (
  watch: SagaWatch,
  stored: Series | null | undefined,
  today: string,
): Candidate[] => {
  const found = new Map(watch.volumes.map((volume) => [Number(volume.number), volume]))
  // The catalogue as the watch leaves it once written in: one created after
  // the watch last looked has none of its dates yet, and would take a volume
  // announced to the day for one out since January.
  const catalogue = stored && withReleases(stored, watch.language, catalogueVolumesOf(watch))
  const edition = catalogue
    ? editionOf(catalogue, { language: watch.language, today })
    : { language: watch.language, today }
  const currentYear = Year(Number(today.slice(0, 4)))
  const candidates = new Map<number, Candidate>()
  for (const entry of catalogue?.volumes ?? []) {
    if (entry.kind !== 'main' || entry.number === undefined) continue
    const number = Number(entry.number)
    if (candidates.has(number)) continue
    const title = entry.titles?.[watch.language] ?? entry.title
    const date = entry.releases?.[watch.language]
    const coverUrl = entry.covers?.[watch.language]
    const known = found.get(number)
    candidates.set(number, {
      volume: {
        number: entry.number,
        title,
        ...(date ? { date } : {}),
        ...(coverUrl ? { coverUrl } : {}),
        ...known,
      },
      upcoming: isForthcoming(entry, currentYear, edition),
    })
  }
  for (const volume of watch.volumes) {
    if (candidates.has(Number(volume.number))) continue
    candidates.set(Number(volume.number), { volume, upcoming: isUpcoming(volume.date, today) })
  }
  return [...candidates.values()]
}

/** What a saga has for the reader: the soonest volume announced that they do
 *  not hold. `books` are the ones they hold of that saga in the watch's
 *  language; `catalogue` the saga's catalogue, whose spine the Series tab
 *  draws — a volume counts as announced by the same rule its strip is drawn
 *  by. */
export const releasesOf = (
  books: readonly Pick<Book, 'series'>[],
  watch: SagaWatch | undefined,
  catalogue: Series | null | undefined,
  today: string,
): SagaReleases => {
  if (!watch) return { watched: false }
  const held = heldNumbersOf(books)
  // The soonest to come out: a volume dated before one announced for a year
  // only by the catalogue, which says less.
  const whenOf = ({ volume }: Candidate) => (volume.date ? lastDayOf(volume.date) : '\uffff')
  const next = candidatesOf(watch, catalogue, today)
    .filter(({ volume, upcoming }) => upcoming && !held.has(volume.number))
    .sort(
      (left, right) =>
        whenOf(left).localeCompare(whenOf(right)) || left.volume.number - right.volume.number,
    )[0]?.volume
  return next ? { watched: true, next } : { watched: true }
}

/** The numbers of the volumes out that the reader does not hold, in order, by
 *  the same rule the Series tab's strip draws them missing: what Découvrir says
 *  can be added. Nothing before the saga was ever looked up. */
export const missingVolumesOf = (
  books: readonly Pick<Book, 'series'>[],
  watch: SagaWatch | undefined,
  catalogue: Series | null | undefined,
  today: string,
): VolumeNumber[] => {
  if (!watch) return []
  const held = heldNumbersOf(books)
  return candidatesOf(watch, catalogue, today)
    .filter(({ volume, upcoming }) => !upcoming && !held.has(volume.number))
    .map(({ volume }) => volume.number)
    .sort((left, right) => left - right)
}

/** Whether a volume can be had now: a recording once Audible's own catalogue
 *  confirmed it, a printed book once it has an ISBN Amazon did not turn
 *  down. */
const isAvailable = (
  volume: Pick<FoundVolume, 'asin' | 'isbn13'>,
  format: ReleaseFormat,
): boolean => (format === 'audiobook' ? volume.asin !== undefined : volume.isbn13 !== undefined)

/** The volumes the saga brought out in the last two weeks that the reader does not
 *  hold and can have now, the newest first: out on a known day — a month
 *  alone does not say it was this fortnight — as the same shared watch the next
 *  volume is read off dates it. A volume announced moves here on its day,
 *  with no new look on the web. */
export const recentReleasesOf = (
  books: readonly Pick<Book, 'series'>[],
  watch: SagaWatch | undefined,
  catalogue: Series | null | undefined,
  today: string,
): FoundVolume[] => {
  if (!watch) return []
  const held = heldNumbersOf(books)
  const since = dayMinus(today, RECENT_DAYS)
  const format = formatOf(watch.seriesId)
  return candidatesOf(watch, catalogue, today)
    .map(({ volume }) => volume)
    .filter(
      (volume) =>
        volume.date?.length === 10 &&
        volume.date <= today &&
        volume.date > since &&
        !held.has(volume.number) &&
        isAvailable(volume, format),
    )
    .sort(
      (left, right) =>
        (right.date as string).localeCompare(left.date as string) || right.number - left.number,
    )
}

/** The tab: every row — a saga, or an author — with something announced for
 *  a known date, the soonest first, then every row with nothing announced but
 *  something just out, the newest first. */
export const inDiscoveryOrder = <
  Row extends { next?: { date?: ReleaseDate }; recent: readonly { date?: ReleaseDate }[] },
>(
  rows: readonly Row[],
): Row[] => {
  const announced = rows
    .filter((row) => row.next?.date)
    .sort((left, right) =>
      lastDayOf(left.next?.date as ReleaseDate).localeCompare(
        lastDayOf(right.next?.date as ReleaseDate),
      ),
    )
  const justOut = rows
    .filter((row) => !row.next?.date && row.recent.length > 0)
    .sort((left, right) =>
      (right.recent[0].date as string).localeCompare(left.recent[0].date as string),
    )
  return [...announced, ...justOut]
}

/** The saga rows of each author: an author's news carries the volumes
 *  announced or just out of the sagas of theirs the Books shelf lists. Who
 *  wrote a saga is read off the reader's own volumes — a saga of two authors
 *  is on both — else off the saga itself. In the rows' order. */
export const sagasByAuthorOf = <
  Row extends { series: Pick<FollowedSeries, 'author'> & { books: Pick<Book, 'authors'>[] } },
>(
  rows: readonly Row[],
): Map<AuthorKey, Row[]> => {
  const byAuthor = new Map<AuthorKey, Row[]>()
  for (const row of rows) {
    const names = row.series.books.flatMap((book) => book.authors)
    const keys = new Set(
      (names.length > 0 ? names : row.series.author ? [row.series.author] : []).map(authorKeyOf),
    )
    for (const key of keys) byAuthor.set(key, [...(byAuthor.get(key) ?? []), row])
  }
  return byAuthor
}

/** How far back an author's works count as news, and are asked for: an author
 *  publishes a few times a year, so a week would leave the shelf empty on its
 *  first look and most weeks after. */
export const AUTHOR_RECENT_DAYS = 90

/** What an author has for the reader in one format: the soonest work
 *  announced, to the day, the month or the year, and the works out in the
 *  last three months, the newest first — dated to the day or to a month over,
 *  and a recording Audible never confirmed too, offered without its link. Left
 *  out, a work the reader holds in that format or awaits in it — matched
 *  on the folded title — and a volume of a saga they hold anything of, which
 *  the Séries shelf already watches or which they set aside. A new saga's
 *  first volume is the author's news. */
export const authorReleasesOf = (
  held: readonly Pick<Book, 'title' | 'format'>[],
  sagaNames: ReadonlySet<string>,
  watch: AuthorWatch | undefined,
  today: string,
  awaitedTitles: ReadonlySet<string> = new Set(),
): { next?: FoundWork; recent: FoundWork[] } => {
  if (!watch) return { recent: [] }
  const titles = new Set([
    ...held
      .filter((book) => releaseFormatOf(book.format) === watch.format)
      .map((book) => slugify(book.title)),
    ...awaitedTitles,
  ])
  const since = dayMinus(today, AUTHOR_RECENT_DAYS)
  const news = watch.works.filter(
    (work) =>
      !titles.has(slugify(work.title)) &&
      !(work.seriesName && sagaNames.has(slugify(work.seriesName))),
  )
  const next = news
    .filter((work) => isUpcoming(work.date, today))
    .sort((left, right) =>
      lastDayOf(left.date as ReleaseDate).localeCompare(lastDayOf(right.date as ReleaseDate)),
    )[0]
  // A month over is out as surely as a day past; a year alone says nothing of
  // the last three months, and one not over is still coming.
  const recent = news
    .filter(
      (work) =>
        work.date !== undefined &&
        work.date.length >= 7 &&
        !isUpcoming(work.date, today) &&
        lastDayOf(work.date) > since,
    )
    .sort((left, right) =>
      lastDayOf(right.date as ReleaseDate).localeCompare(lastDayOf(left.date as ReleaseDate)),
    )
  return next ? { next, recent } : { recent }
}

// MARK: - Alerts

export type DueAlert = { key: string; watch: SagaWatch; volume: FoundVolume }

/** The volumes whose alert is due for a reader: out on a known day, today or
 *  in the last two weeks, of a saga they still follow, not pushed yet. */
export const dueAlertsOf = (
  reader: DiscoveryReader,
  watches: ReadonlyMap<string, SagaWatch>,
  today: string,
): DueAlert[] => {
  const since = dayMinus(today, ALERT_GRACE_DAYS)
  const notified = new Set(reader.notified)
  return reader.sagas.flatMap((saga) => {
    const watch = watches.get(watchKeyOf(saga))
    if (!watch) return []
    return watch.volumes.flatMap((volume) => {
      const key = `${watch.key}--${volume.number}`
      const date = volume.date
      return date && date.length === 10 && date <= today && date >= since && !notified.has(key)
        ? [{ key, watch, volume }]
        : []
    })
  })
}

/** The alert for one volume, in the reader's language. Worded for the day it
 *  goes out, which may be a little after the volume did. */
export const alertOf = (
  { watch, volume }: DueAlert,
  language: Language,
): { title: string; body: string } => {
  const audio = formatOf(watch.seriesId) === 'audiobook'
  if (language === 'fr')
    return {
      title: 'Nouveau tome',
      body: `« ${volume.title} », tome ${volume.number} de ${watch.name}, est sorti${audio ? ' en livre audio' : ''}.`,
    }
  return {
    title: 'New volume',
    body: `"${volume.title}", book ${volume.number} of ${watch.name}, is out${audio ? ' as an audiobook' : ''}.`,
  }
}

// MARK: - The weekly digest

/** How many volumes the digest names before it counts the rest. */
const DIGEST_NAMED = 4

export type Announcement = { key: string; watch: SagaWatch; volume: FoundVolume }

/** The volumes to name in a reader's weekly digest: announced for a known
 *  date — a day, a month or a year — by the rule Découvrir lists them by, of a
 *  saga they follow, not held, and never named in a digest before. The
 *  soonest first. */
export const newAnnouncementsOf = (
  followed: readonly FollowedSeries[],
  watches: ReadonlyMap<string, SagaWatch>,
  announced: ReadonlySet<string>,
  today: string,
): Announcement[] =>
  followed
    .flatMap((series): Announcement[] => {
      if (!isDiscoverable(series)) return []
      const watch = watches.get(watchKeyOf({ seriesId: series.id, language: series.language }))
      if (!watch) return []
      const held = heldNumbersOf(series.books)
      return candidatesOf(watch, series.catalogue, today).flatMap(({ volume, upcoming }) => {
        const key = `${watch.key}--${volume.number}`
        return upcoming && volume.date && !held.has(volume.number) && !announced.has(key)
          ? [{ key, watch, volume }]
          : []
      })
    })
    .sort(
      (left, right) =>
        lastDayOf(left.volume.date as ReleaseDate).localeCompare(
          lastDayOf(right.volume.date as ReleaseDate),
        ) || left.volume.number - right.volume.number,
    )

const MONTHS: Record<Language, readonly string[]> = {
  fr: [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ],
  en: [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ],
}

/** When a volume comes out, as precisely as it was announced, the year left
 *  out when it is this one: "le 8 octobre", "en novembre", "en 2027". */
const whenOf = (date: ReleaseDate, language: Language, today: string): string => {
  const [year, month, day] = date.split('-')
  const thisYear = year === today.slice(0, 4)
  const monthName = month ? MONTHS[language][Number(month) - 1] : undefined
  if (language === 'fr') {
    const suffix = thisYear ? '' : ` ${year}`
    if (day) return `le ${Number(day) === 1 ? '1er' : Number(day)} ${monthName}${suffix}`
    return monthName ? `en ${monthName}${suffix}` : `en ${year}`
  }
  const suffix = thisYear ? '' : `, ${year}`
  if (day) return `on ${monthName} ${Number(day)}${suffix}`
  return monthName ? `in ${monthName}${thisYear ? '' : ` ${year}`}` : `in ${year}`
}

/** The weekly digest: one notification naming the volumes newly announced,
 *  one per line, the soonest first, and counting the ones past the fourth. */
export const digestOf = (
  announcements: readonly Announcement[],
  language: Language,
  today: string,
): { title: string; body: string } => {
  const named = announcements.slice(0, DIGEST_NAMED).map(({ watch, volume }) => {
    const when = whenOf(volume.date as ReleaseDate, language, today)
    return language === 'fr'
      ? `${watch.name}, tome ${volume.number}, ${when}`
      : `${watch.name}, book ${volume.number}, ${when}`
  })
  const rest = announcements.length - named.length
  if (rest > 0)
    named.push(language === 'fr' ? `et ${rest} autre${rest > 1 ? 's' : ''}` : `and ${rest} more`)
  return {
    title: language === 'fr' ? 'Prochaines sorties' : 'Coming soon',
    body: named.join('\n'),
  }
}

// MARK: - A fresh look

/** What a fresh search found, laid over the last one: a volume found again
 *  takes what was found of it now, keeping the cover and the confirmed ASIN
 *  the new answer lacks; a volume missed this time stays — a search that misses
 *  a volume does not unmake it. */
export const mergedVolumes = (
  previous: readonly FoundVolume[],
  found: readonly FoundVolume[],
): FoundVolume[] => {
  const merged = new Map(previous.map((volume) => [volume.number, volume]))
  for (const volume of found) {
    const known = merged.get(volume.number)
    merged.set(volume.number, {
      ...volume,
      ...(volume.coverUrl || !known?.coverUrl ? {} : { coverUrl: known.coverUrl }),
      ...(volume.asin || !known?.asin ? {} : { asin: known.asin }),
    })
  }
  return [...merged.values()].sort((left, right) => left.number - right.number)
}

/** How long a work out stays on an author's watch: past a year it is no
 *  longer news, and the watch must not grow with every look. */
const KEPT_DAYS = 365

/** What a fresh search of an author found, laid over the last one, as
 *  `mergedVolumes` does for a saga but matched on the folded title: a work
 *  found again takes what was found of it now, keeping the cover and the
 *  confirmed ASIN the new answer lacks; a work missed this time stays while it
 *  is less than a year old. */
export const mergedWorks = (
  previous: readonly FoundWork[],
  found: readonly FoundWork[],
  today: string,
): FoundWork[] => {
  const since = dayMinus(today, KEPT_DAYS)
  const merged = new Map(
    previous
      .filter((work) => work.date !== undefined && lastDayOf(work.date) > since)
      .map((work) => [slugify(work.title), work]),
  )
  for (const work of found) {
    const known = merged.get(slugify(work.title))
    merged.set(slugify(work.title), {
      ...work,
      ...(work.coverUrl || !known?.coverUrl ? {} : { coverUrl: known.coverUrl }),
      ...(work.asin || !known?.asin ? {} : { asin: known.asin }),
    })
  }
  return [...merged.values()].sort((left, right) =>
    (left.date ?? '').localeCompare(right.date ?? ''),
  )
}

/** A saga heard as Audible lists it: every recording Audible sells or has on
 *  preorder, with Audible's own day — a recording is out when Audible sells
 *  it, not when the book or another language's recording came out. What the
 *  web found beyond Audible's list is kept only while it is announced: nothing
 *  Audible does not sell counts as out. */
export const onAudible = (
  listed: readonly FoundVolume[],
  found: readonly FoundVolume[],
  today: string,
): FoundVolume[] => {
  const numbers = new Set(listed.map((volume) => volume.number))
  const announced = found.filter(
    (volume) => !numbers.has(volume.number) && isUpcoming(volume.date, today),
  )
  return [...listed, ...announced].sort((left, right) => left.number - right.number)
}

/** What an announced volume's page is built from, before anything is
 *  described: the title and author the watch found, the recording's own when
 *  Audible sells it, in the saga's format and the edition's language. */
export const announcedEditionOf = (
  watch: SagaWatch,
  volume: FoundVolume,
  recording: AudibleRecording | undefined,
): ScanResult => ({
  recognized: true,
  title: recording?.title ?? volume.title,
  authors: recording?.authors.length ? recording.authors : watch.author ? [watch.author] : [],
  format: formatOf(watch.seriesId),
  publisher: recording?.publisher,
  language: watch.language,
  subgenres: [],
})

/** An announced volume's page: what the model described, over what the watch
 *  and Audible already knew. Audible's facts about its own recording — cover,
 *  narrators, running time, publisher — win over the model's; the model's
 *  summary wins over Audible's blurb, which is marketing copy. The volume stays
 *  where the watch found it, in its saga and edition, whatever the model says. */
export const announcedPreviewOf = (
  watch: SagaWatch,
  volume: FoundVolume,
  recording: AudibleRecording | undefined,
  described: ScanResult,
): AnnouncedVolumePreview => {
  const seen = announcedEditionOf(watch, volume, recording)
  const heard = seen.format === 'audiobook'
  return {
    book: {
      ...described,
      recognized: true,
      title: seen.title,
      authors: seen.authors.length > 0 ? seen.authors : described.authors,
      format: seen.format,
      publisher: recording?.publisher ?? described.publisher,
      synopsis: described.synopsis ?? recording?.synopsis,
      language: watch.language,
      // A recording has no pages, and the ISBN the model finds is the print's.
      pageCount: heard ? undefined : described.pageCount,
      isbn13: heard ? undefined : (volume.isbn13 ?? described.isbn13),
      coverUrl: recording?.coverUrl ?? volume.coverUrl ?? described.coverUrl,
      series: { id: watch.seriesId, name: watch.name, volume: volume.number, kind: 'main' },
    },
    narrators: recording?.narrators ?? [],
    durationMinutes: recording?.durationMinutes,
    releaseDate: volume.date,
    asin: volume.asin,
  }
}
