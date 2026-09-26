import type { Book, BookLanguage } from '~/domain/book/types'
import { type FoundVolume as CatalogueVolume, isForthcoming } from '~/domain/series/business-rules'
import { isAudioSeries } from '~/domain/series/primitives'
import type { Series, SeriesId } from '~/domain/series/types'
import type { FollowedSeries } from '~/domain/series/use-case'
import { type Language, SUPPORTED_LANGUAGES } from '~/domain/shared/language'
import { Year } from '~/domain/shared/primitives'
import type {
  DiscoveryReader,
  FoundVolume,
  OfferedVolume,
  ReleaseDate,
  ReleaseFormat,
  SagaDiscovery,
  SagaReleases,
  SagaWatch,
  WatchedSaga,
} from './types'

/** How often the web is searched again for one saga: a publisher announces a
 *  volume months ahead, and the grounded call is the expensive part. */
export const WATCH_EVERY_MS = 7 * 86_400_000
/** How often the hourly pass reads a reader's library again to learn which
 *  sagas they follow. Opening the tab does it at once. */
export const SYNC_EVERY_MS = 86_400_000
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

/** Every saga the reader follows, in the language they hold it in: all of
 *  them but the ones they set aside. A saga of books that record no language
 *  cannot be searched for. */
export const watchedSagasOf = (followed: readonly FollowedSeries[]): WatchedSaga[] => {
  const sagas = new Map<string, WatchedSaga>()
  for (const saga of followed) {
    if (!saga.language || saga.state === 'unfollowed') continue
    const watched: WatchedSaga = {
      seriesId: saga.id,
      language: saga.language,
      name: saga.name,
      ...(saga.author ? { author: saga.author } : {}),
    }
    sagas.set(watchKeyOf(watched), watched)
  }
  return [...sagas.values()]
}

/** Whether a saga is due for another look on the web. */
export const watchIsStale = (watch: SagaWatch | undefined, now: Date): boolean =>
  !watch || now.getTime() - watch.checkedAt.getTime() > WATCH_EVERY_MS

/** Whether the hourly pass must read this reader's library again. */
export const readerIsStale = (reader: DiscoveryReader | undefined, now: Date): boolean =>
  !reader || now.getTime() - reader.syncedAt.getTime() > SYNC_EVERY_MS

/** The sagas every reader follows, each once, the ones never looked up first,
 *  then the longest unchecked. */
export const dueWatches = (
  readers: readonly DiscoveryReader[],
  watches: ReadonlyMap<string, SagaWatch>,
  now: Date,
): WatchedSaga[] => {
  const sagas = new Map<string, WatchedSaga>()
  for (const reader of readers) for (const saga of reader.sagas) sagas.set(watchKeyOf(saga), saga)
  const checkedAt = (saga: WatchedSaga) => watches.get(watchKeyOf(saga))?.checkedAt.getTime() ?? 0
  return [...sagas.values()]
    .filter((saga) => watchIsStale(watches.get(watchKeyOf(saga)), now))
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

// MARK: - Where to get a volume

/** The Amazon store for each language a book is sold in; English and anything
 *  else goes to the American one. */
const AMAZON_DOMAINS: Partial<Record<BookLanguage, string>> = {
  fr: 'amazon.fr',
  de: 'amazon.de',
  es: 'amazon.es',
  it: 'amazon.it',
  nl: 'amazon.nl',
  sv: 'amazon.se',
  pl: 'amazon.pl',
  tr: 'amazon.com.tr',
  ja: 'amazon.co.jp',
  pt: 'amazon.com.br',
}

/** The Audible store for each language a recording is sold in. */
export const AUDIBLE_DOMAINS: Partial<Record<BookLanguage, string>> = {
  fr: 'audible.fr',
  de: 'audible.de',
  es: 'audible.es',
  it: 'audible.it',
  ja: 'audible.co.jp',
}

const audibleDomainOf = (language: BookLanguage) => AUDIBLE_DOMAINS[language] ?? 'audible.com'

/** A search on Amazon: by ISBN, which lands on the very edition, else by title
 *  and author. */
export const amazonUrlOf = (volume: FoundVolume, watch: SagaWatch): string => {
  const keywords = volume.isbn13 ?? [volume.title, watch.author].filter(Boolean).join(' ')
  return `https://www.${AMAZON_DOMAINS[watch.language] ?? 'amazon.com'}/s?k=${encodeURIComponent(keywords)}`
}

/** The recording's own page on Audible, once Audible confirmed it; a search
 *  for its title otherwise. */
export const audibleUrlOf = (volume: FoundVolume, watch: SagaWatch): string => {
  const domain = audibleDomainOf(watch.language)
  if (volume.asin) return `https://www.${domain}/pd/${volume.asin}`
  const keywords = [volume.title, watch.author].filter(Boolean).join(' ')
  return `https://www.${domain}/search?keywords=${encodeURIComponent(keywords)}`
}

const offered = (volume: FoundVolume, watch: SagaWatch): OfferedVolume =>
  formatOf(watch.seriesId) === 'audiobook'
    ? { ...volume, store: 'audible', storeUrl: audibleUrlOf(volume, watch) }
    : { ...volume, store: 'amazon', storeUrl: amazonUrlOf(volume, watch) }

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
  catalogue: Series | null | undefined,
  today: string,
): Candidate[] => {
  const found = new Map(watch.volumes.map((volume) => [Number(volume.number), volume]))
  const edition = { language: watch.language, today }
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

/** What a saga has for the reader: every volume out that they do not hold, in
 *  order, and the soonest one announced. `books` are the ones they hold of that
 *  saga in the watch's language; `catalogue` the saga's catalogue, whose spine
 *  the Series tab draws — Découvrir offers the same volumes it shows missing. */
export const releasesOf = (
  books: readonly Pick<Book, 'series'>[],
  watch: SagaWatch | undefined,
  catalogue: Series | null | undefined,
  today: string,
): SagaReleases => {
  if (!watch) return { watched: false, available: [] }
  const held = heldNumbersOf(books)
  const missing = candidatesOf(watch, catalogue, today).filter(
    ({ volume }) => !held.has(volume.number),
  )
  const available = missing
    .filter(({ upcoming }) => !upcoming)
    .map(({ volume }) => volume)
    .sort((left, right) => left.number - right.number)
    .map((volume) => offered(volume, watch))
  // The soonest to come out: a volume dated before one announced for a year
  // only by the catalogue, which says less.
  const whenOf = ({ volume }: Candidate) => (volume.date ? lastDayOf(volume.date) : '\uffff')
  const next = missing
    .filter(({ upcoming }) => upcoming)
    .sort(
      (left, right) =>
        whenOf(left).localeCompare(whenOf(right)) || left.volume.number - right.volume.number,
    )[0]?.volume
  return next
    ? { watched: true, available, next: offered(next, watch) }
    : { watched: true, available }
}

/** The tab: every saga with something to say, those with volumes to get first
 *  — the most recently shelved first — then those with only an announcement,
 *  the soonest first. */
export const inDiscoveryOrder = (rows: readonly SagaDiscovery[]): SagaDiscovery[] => {
  const withVolumes = rows
    .filter((row) => row.available.length > 0)
    .sort((left, right) => right.series.shelvedAt.getTime() - left.series.shelvedAt.getTime())
  const announced = rows
    .filter((row) => row.available.length === 0 && row.next?.date)
    .sort((left, right) =>
      lastDayOf(left.next?.date as ReleaseDate).localeCompare(
        lastDayOf(right.next?.date as ReleaseDate),
      ),
    )
  return [...withVolumes, ...announced]
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
