import { AdminCommand } from '~/domain/admin/command'
import type { ShelvedAuthor } from '~/domain/author/types'
import { AuthorUseCase } from '~/domain/author/use-case'
import { BookQuery } from '~/domain/book/query'
import type { Book, BookLanguage } from '~/domain/book/types'
import {
  alertOf,
  announcedEditionOf,
  announcedPreviewOf,
  authorReleasesOf,
  authorWatchKeyOf,
  catalogueVolumesOf,
  digestOf,
  dueAlertsOf,
  dueAuthorWatches,
  dueWatches,
  formatOf,
  inDiscoveryOrder,
  isDiscoverable,
  likelyLanguageOf,
  mergedVolumes,
  mergedWorks,
  missingVolumesOf,
  newAnnouncementsOf,
  onAudible,
  readerIsStale,
  recentReleasesOf,
  releasesOf,
  todayOf,
  watchedAuthorsOf,
  watchedSagasOf,
  watchKeyOf,
} from '~/domain/discovery/business-rules'
import { DiscoveryCommand } from '~/domain/discovery/command'
import { amazonEditionOf } from '~/domain/discovery/infrastructure/amazon-catalogue'
import {
  audibleEditionOf,
  audibleProductOf,
  audibleRecordingOf,
  audibleSeriesOf,
} from '~/domain/discovery/infrastructure/audible-catalogue'
import { volumesFrom, worksFrom } from '~/domain/discovery/parsing'
import { authorReleasesPrompt, releasesPrompt } from '~/domain/discovery/prompts'
import { DiscoveryQuery } from '~/domain/discovery/query'
import {
  AUTHOR_RELEASES_SCHEMA,
  type AuthorReleasesOutput,
  RELEASES_SCHEMA,
  type ReleasesOutput,
} from '~/domain/discovery/schemas'
import type {
  AnnouncedVolumePreview,
  AudibleRecording,
  AuthorDiscovery,
  AuthorWatch,
  Discovery,
  DiscoveryReader,
  FoundVolume,
  FoundWork,
  ReleaseFormat,
  SagaDiscovery,
  SagaReleases,
  SagaWatch,
  WatchedAuthor,
  WatchedSaga,
} from '~/domain/discovery/types'
import { NotificationUseCase } from '~/domain/notification/use-case'
import { generate } from '~/domain/scan/gemini'
import { publishedCoverOf } from '~/domain/scan/published-cover'
import type { ScanResult } from '~/domain/scan/types'
import { type ScanOutcome, ScanUseCase } from '~/domain/scan/use-case'
import { SeriesCommand } from '~/domain/series/command'
import { SeriesQuery } from '~/domain/series/query'
import type { SeriesId, VolumeNumber } from '~/domain/series/types'
import { type FollowedSeries, SeriesUseCase } from '~/domain/series/use-case'
import type { Language } from '~/domain/shared/language'
import type { AuthorName, BookTitle, UserId } from '~/domain/shared/types'
import { UserQuery } from '~/domain/user/query'
import { createLogger } from '~/system/logger'
import { withRequestCacheScope } from '~/system/request-cache'
import { slugify } from '~/utils/slug'

const logger = createLogger('discovery')

/** How many grounded calls run side by side: a library of sagas is caught up
 *  over a few hours rather than in one request the function would not live
 *  through. */
const CALLS_AT_ONCE = 5

/** Two thirds of the function's 180s ceiling, as the Audible sync keeps: the
 *  budget is checked between steps, so a run overshoots by one step. */
const SCHEDULED_BUDGET_MS = 120_000

/** What a first look at the tab may spend before answering: the app waits
 *  behind a loader, and the request must live through it. */
const ON_DEMAND_BUDGET_MS = 90_000

export namespace DiscoveryUseCase {
  /** The recording Audible sells of a book in its language, by its title and
   *  first author: `unknown` when there is none, `unreachable` when Audible
   *  could not be asked. */
  export const audioEditionOf = (
    title: BookTitle,
    author: AuthorName | undefined,
    language: BookLanguage,
  ): Promise<AudibleRecording | 'unknown' | 'unreachable'> =>
    audibleEditionOf(title, author, language)

  /** The tab as the reader opens it: every saga they follow in that format
   *  with a volume announced they do not hold or one just out, and every
   *  author they hold in that format with a work announced or just out outside
   *  those sagas, as the shared watches know them, and how many were never
   *  looked up. Opening it tells the hourly pass at once which sagas and
   *  authors the reader follows now, and in which language to write to them. */
  export const discover = async (
    userId: UserId,
    language: Language,
    format: ReleaseFormat,
    now = new Date(),
  ): Promise<Discovery> => {
    const library = await libraryOf(userId)
    await rememberReader(userId, library, language, now)
    const { watches, authorWatches } = await watchesOf(library, format)
    return discoveryOf(library, watches, authorWatches, format, now)
  }

  /** The first look at the tab: every saga, then every author, the reader
   *  follows in that format that was never looked up is looked up now, a few
   *  side by side, rather than on the next hourly pass — within a budget the
   *  request lives through; whatever is left goes to the hourly pass. Answers
   *  the tab. */
  export const lookUpUnwatched = async (
    userId: UserId,
    language: Language,
    format: ReleaseFormat,
    now = new Date(),
    budgetMs = ON_DEMAND_BUDGET_MS,
    startedAt = Date.now(),
  ): Promise<Discovery> => {
    const library = await libraryOf(userId)
    await rememberReader(userId, library, language, now)
    const { watches, authorWatches } = await watchesOf(library, format)
    const overBudget = () => Date.now() - startedAt > budgetMs
    const unwatched = library.sagas.filter(
      (saga) => formatOf(saga.seriesId) === format && !watches.has(watchKeyOf(saga)),
    )
    await lookUpAll(unwatched, watches, now, overBudget)
    const unwatchedAuthors = library.authors.filter(
      (author) => author.format === format && !authorWatches.has(authorWatchKeyOf(author)),
    )
    await lookUpAllAuthors(unwatchedAuthors, authorWatches, now, overBudget)
    return discoveryOf(library, watches, authorWatches, format, now)
  }

  /** What the saga screen shows under its introduction: the next volume
   *  announced the reader does not hold, in the edition they opened. Nothing
   *  for an edition nobody looked up yet. */
  export const sagaReleases = async (
    userId: UserId,
    seriesId: SeriesId,
    language: BookLanguage,
    now = new Date(),
  ): Promise<SagaReleases> => {
    const [books, watches, catalogue] = await Promise.all([
      BookQuery.bySeries(userId, seriesId),
      DiscoveryQuery.watches([watchKeyOf({ seriesId, language })]),
      SeriesQuery.byId(seriesId),
    ])
    return releasesOf(
      books.filter((book) => book.language === language),
      watches.get(watchKeyOf({ seriesId, language })),
      catalogue,
      todayOf(now),
    )
  }

  /** A saga screen opened on an edition nobody looked up yet: it is looked up
   *  now, one grounded call, and its section answered. An edition already
   *  looked up is answered as it stands. A saga with neither a volume held
   *  nor a catalogue has no name to search the web with. */
  export const lookUpSaga = async (
    userId: UserId,
    seriesId: SeriesId,
    language: BookLanguage,
    now = new Date(),
  ): Promise<SagaReleases> => {
    const key = watchKeyOf({ seriesId, language })
    const [books, watches, catalogue] = await Promise.all([
      BookQuery.bySeries(userId, seriesId),
      DiscoveryQuery.watches([key]),
      SeriesQuery.byId(seriesId),
    ])
    const held = books.filter((book) => book.language === language)
    const lookingUp = !watches.has(key)
    if (lookingUp) {
      const name = held[0]?.series?.name ?? catalogue?.name
      const author = held[0]?.authors[0] ?? catalogue?.author
      const asin = held.find((book) => book.audibleAsin)?.audibleAsin
      if (name)
        await lookUpAll(
          [{ seriesId, language, name, ...(author ? { author } : {}), ...(asin ? { asin } : {}) }],
          watches,
          now,
          () => false,
        )
    }
    // The catalogue as the lookup left it, the dates it found written in.
    const written = lookingUp && watches.has(key) ? await SeriesQuery.byId(seriesId) : catalogue
    return releasesOf(held, watches.get(key), written, todayOf(now))
  }

  /** A volume announced, described for its page before the reader adds it.
   *  A printed one is described by the model from the title and author the
   *  watch found; a recording Audible confirmed is read off Audible's own
   *  catalogue first — cover, narrators, running time, blurb — and the model
   *  adds what Audible does not say: summary, genre, first publication.
   *
   *  Spends one scan, as a typed title does, and is never kept. `not-found`
   *  for a volume no watch announced in that edition, so it is never a free
   *  lookup of any title. */
  export const previewAnnouncedVolume = async (
    userId: UserId,
    {
      seriesId,
      language,
      number,
    }: { seriesId: SeriesId; language: BookLanguage; number: VolumeNumber },
    appLanguage: Language,
  ): Promise<AnnouncedVolumePreview | 'not-found' | Exclude<ScanOutcome, ScanResult>> => {
    const key = watchKeyOf({ seriesId, language })
    const watch = (await DiscoveryQuery.watches([key])).get(key)
    const volume = watch?.volumes.find((found) => found.number === number)
    if (!watch || !volume) return 'not-found'
    const heard = volume.asin ? await audibleRecordingOf(volume.asin, language) : undefined
    const recording = typeof heard === 'object' ? heard : undefined
    const described = await ScanUseCase.lookUpEdition(
      userId,
      announcedEditionOf(watch, volume, recording),
      appLanguage,
    )
    if (described === 'quota-exhausted' || 'failed' in described) return described
    return announcedPreviewOf(watch, volume, recording, described)
  }

  /** The hourly pass. First every reader whose sagas and authors were last
   *  worked out a day ago has their library read again; then every saga
   *  anybody follows whose watch is a week old is looked up on the web — the
   *  ones never looked up first — and what was found written into its
   *  catalogue; then every author, the same way. All stop when the budget is
   *  spent; whatever is not reached goes first next hour. */
  export const watchDueSagas = async (
    now = new Date(),
    budgetMs = SCHEDULED_BUDGET_MS,
    startedAt = Date.now(),
  ): Promise<{ synced: number; watched: number; failed: number; deferred: number }> => {
    const overBudget = () => Date.now() - startedAt > budgetMs
    const [userIds, stored] = await Promise.all([UserQuery.allIds(), DiscoveryQuery.allReaders()])
    const readers = new Map(stored.map((reader) => [reader.userId, reader]))
    let synced = 0
    let failed = 0
    for (const userId of userIds) {
      if (overBudget()) break
      const reader = readers.get(userId)
      if (!readerIsStale(reader, now)) continue
      try {
        const library = await withRequestCacheScope(() => libraryOf(userId, reader))
        const language = reader?.language ?? likelyLanguageOf(library.sagas)
        readers.set(userId, await rememberReader(userId, library, language, now, true))
        synced += 1
      } catch (error) {
        failed += 1
        logger.warn('discovery reader sync failed', { error, userId })
      }
    }
    const everyone = [...readers.values()]
    const [watches, authorWatches] = await Promise.all([
      DiscoveryQuery.watches(everyone.flatMap((reader) => reader.sagas.map(watchKeyOf))),
      DiscoveryQuery.authorWatches(
        everyone.flatMap((reader) => (reader.authors ?? []).map(authorWatchKeyOf)),
      ),
    ])
    const sagas = await lookUpAll(dueWatches(everyone, watches, now), watches, now, overBudget)
    const authors = await lookUpAllAuthors(
      dueAuthorWatches(everyone, authorWatches, now),
      authorWatches,
      now,
      overBudget,
    )
    return {
      synced,
      watched: sagas.watched + authors.watched,
      failed: failed + sagas.failed + authors.failed,
      deferred: sagas.deferred + authors.deferred,
    }
  }

  /** The morning pass: every volume that came out, pushed to the readers who
   *  follow its saga, once. No model and no library is read; the hourly pass
   *  already knows the dates and the sagas. */
  export const sendAlertsToEveryReader = async (now = new Date()): Promise<{ readers: number }> => {
    const readers = await DiscoveryQuery.allReaders()
    const watches = await DiscoveryQuery.watches(
      readers.flatMap((reader) => reader.sagas.map(watchKeyOf)),
    )
    let reached = 0
    for (const reader of readers) {
      const due = dueAlertsOf(reader, watches, todayOf(now))
      if (due.length === 0) continue
      try {
        for (const alert of due)
          await NotificationUseCase.notify(reader.userId, {
            kind: 'translation',
            ...alertOf(alert, reader.language),
            link: 'shiori://discover',
          })
        await DiscoveryCommand.markNotified(
          reader,
          due.map((alert) => alert.key),
        )
        reached += 1
      } catch (error) {
        logger.warn('release alerts failed', { error, userId: reader.userId })
      }
    }
    return { readers: reached }
  }

  /** The Sunday digest: one notification per reader naming the volumes newly
   *  announced for a known date in the sagas they follow, the ones they hold
   *  left out, each named once. No model is called; each reader's library is
   *  read to know what they hold. A reader with nothing new hears nothing. */
  export const sendDigestToEveryReader = async (now = new Date()): Promise<{ readers: number }> => {
    const readers = await DiscoveryQuery.allReaders()
    const watches = await DiscoveryQuery.watches(
      readers.flatMap((reader) => reader.sagas.map(watchKeyOf)),
    )
    const today = todayOf(now)
    let reached = 0
    for (const reader of readers) {
      try {
        const followed = await withRequestCacheScope(() => SeriesUseCase.followed(reader.userId))
        const due = newAnnouncementsOf(followed, watches, new Set(reader.announced ?? []), today)
        if (due.length === 0) continue
        await NotificationUseCase.notify(reader.userId, {
          kind: 'digest',
          ...digestOf(due, reader.language, today),
          link: 'shiori://discover',
        })
        await DiscoveryCommand.markAnnounced(
          reader,
          due.map((announcement) => announcement.key),
        )
        reached += 1
      } catch (error) {
        logger.warn('release digest failed', { error, userId: reader.userId })
      }
    }
    return { readers: reached }
  }
}

// MARK: - The parts of a pass

/** What the tab is worked out from: the reader's sagas and authors, and which
 *  of them are watched. */
type Library = {
  followed: FollowedSeries[]
  shelved: ShelvedAuthor<Book>[]
  sagas: WatchedSaga[]
  authors: WatchedAuthor[]
  known: DiscoveryReader | undefined
}

/** The reader's sagas and authors, and what the passes know of them. The
 *  library is read once, shared by the sagas and the authors. */
const libraryOf = async (userId: UserId, known?: DiscoveryReader): Promise<Library> => {
  const [followed, shelved, reader] = await Promise.all([
    SeriesUseCase.followed(userId),
    AuthorUseCase.shelvedAuthors(userId),
    known ? Promise.resolve(known) : DiscoveryQuery.reader(userId),
  ])
  return {
    followed,
    shelved,
    sagas: watchedSagasOf(followed),
    authors: watchedAuthorsOf(shelved),
    known: reader,
  }
}

/** The watches the tab needs: every saga's, and the authors' of that format
 *  only — each in one getAll. */
const watchesOf = async (library: Library, format: ReleaseFormat) => {
  const [watches, authorWatches] = await Promise.all([
    DiscoveryQuery.watches(library.sagas.map(watchKeyOf)),
    DiscoveryQuery.authorWatches(
      library.authors.filter((author) => author.format === format).map(authorWatchKeyOf),
    ),
  ])
  return { watches, authorWatches }
}

/** The tab in one format out of the reader's library and the watches. */
const discoveryOf = async (
  library: Library,
  watches: ReadonlyMap<string, SagaWatch>,
  authorWatches: ReadonlyMap<string, AuthorWatch>,
  format: ReleaseFormat,
  now: Date,
): Promise<Discovery> => {
  const today = todayOf(now)
  let unwatched = 0
  let followedCount = 0
  const rows = library.followed.flatMap((series): SagaDiscovery[] => {
    if (!isDiscoverable(series)) return []
    if (formatOf(series.id) !== format) return []
    followedCount += 1
    const watch = watches.get(watchKeyOf({ seriesId: series.id, language: series.language }))
    const releases = releasesOf(series.books, watch, series.catalogue, today)
    if (!releases.watched) unwatched += 1
    const recent = recentReleasesOf(series.books, watch, series.catalogue, today)
    if (!releases.next && recent.length === 0) return []
    const missing = missingVolumesOf(series.books, watch, series.catalogue, today)
    return [{ ...releases, series, missing, recent }]
  })
  const authors = await authorRowsOf(library, authorWatches, format, today)
  return {
    sagas: inDiscoveryOrder(rows),
    authors: authors.rows,
    unwatched: unwatched + authors.unwatched,
    followed: followedCount + authors.followed,
  }
}

/** The Authors shelf in one format: every author the reader holds in it with
 *  a work announced or just out, outside any saga they hold — read or heard,
 *  followed or set aside — in the tab's order, with their portraits. */
const authorRowsOf = async (
  library: Library,
  watches: ReadonlyMap<string, AuthorWatch>,
  format: ReleaseFormat,
  today: string,
): Promise<{ rows: AuthorDiscovery[]; unwatched: number; followed: number }> => {
  const shelved = new Map(library.shelved.map((author) => [author.key, author]))
  const sagaNames = new Set([
    ...library.followed.map((series) => slugify(series.name)),
    ...library.shelved.flatMap((author) =>
      author.books.flatMap((book) => (book.series ? [slugify(book.series.name)] : [])),
    ),
  ])
  const watched = library.authors.filter((author) => author.format === format)
  let unwatched = 0
  const rows = watched.flatMap((watchedAuthor) => {
    const watch = watches.get(authorWatchKeyOf(watchedAuthor))
    const author = shelved.get(watchedAuthor.authorKey)
    if (!watch) unwatched += 1
    if (!watch || !author) return []
    const releases = authorReleasesOf(author.books, sagaNames, watch, today)
    if (!releases.next && releases.recent.length === 0) return []
    return [{ ...releases, author }]
  })
  const ordered = inDiscoveryOrder(rows)
  const portrayed = await AuthorUseCase.withPortraits(ordered.map((row) => row.author))
  return {
    rows: ordered.map((row, index) => ({ ...row, author: portrayed[index] ?? row.author })),
    unwatched,
    followed: watched.length,
  }
}

/** Look these sagas up on the web, a few side by side, until the budget is
 *  spent, keeping each watch in `watches` and writing what was found into the
 *  sagas' catalogues. A lookup that fails leaves its saga as it was. */
const lookUpAll = async (
  sagas: readonly WatchedSaga[],
  watches: Map<string, SagaWatch>,
  now: Date,
  overBudget: () => boolean,
): Promise<{ watched: number; failed: number; deferred: number }> => {
  let watched = 0
  let failed = 0
  for (let start = 0; start < sagas.length; start += CALLS_AT_ONCE) {
    if (overBudget()) return { watched, failed, deferred: sagas.length - start }
    const found = await Promise.all(
      sagas.slice(start, start + CALLS_AT_ONCE).map(async (saga) => {
        try {
          return await lookUp(saga, watches.get(watchKeyOf(saga)), now)
        } catch (error) {
          failed += 1
          logger.warn('saga release lookup failed', { error, saga: watchKeyOf(saga) })
          return undefined
        }
      }),
    )
    // One after the other: a saga followed in two languages would otherwise
    // have each write overwrite the other's from the same stale read.
    for (const watch of found) {
      if (!watch) continue
      watched += 1
      watches.set(watch.key, watch)
      try {
        await SeriesCommand.recordReleases(
          watch.seriesId,
          watch.language,
          catalogueVolumesOf(watch),
        )
      } catch (error) {
        logger.warn('release dates not recorded', { error, saga: watch.key })
      }
    }
  }
  return { watched, failed, deferred: 0 }
}

/** Keep what the passes need to know of a reader, writing only when it moved:
 *  opening the tab every few minutes must not cost a write each time. */
const rememberReader = async (
  userId: UserId,
  { sagas, authors, known }: Pick<Library, 'sagas' | 'authors' | 'known'>,
  language: Language,
  now: Date,
  force = false,
): Promise<DiscoveryReader> => {
  const unchanged =
    known !== undefined &&
    known.language === language &&
    JSON.stringify(known.sagas) === JSON.stringify(sagas) &&
    JSON.stringify(known.authors ?? []) === JSON.stringify(authors) &&
    !readerIsStale(known, now)
  if (unchanged && !force) return known
  return DiscoveryCommand.saveReader({
    userId,
    language,
    sagas,
    authors,
    syncedAt: now,
    notified: known?.notified ?? [],
    ...(known?.announced ? { announced: known.announced } : {}),
  })
}

const recordUsage = async (
  usage: Parameters<typeof AdminCommand.recordDiscoveryUsage>[0] | undefined,
) => {
  if (!usage) return
  try {
    await AdminCommand.recordDiscoveryUsage(usage)
  } catch (error) {
    logger.warn('discovery usage not recorded', { error })
  }
}

/** A printed volume's cover, found by its ISBN, unless the last look already
 *  found it for that ISBN. One that cannot be found goes without. */
const withCover = async <Found extends Pick<FoundVolume, 'coverUrl' | 'isbn13'>>(
  volume: Found,
  known: Found | undefined,
): Promise<Found> => {
  if (volume.coverUrl || !volume.isbn13) return volume
  if (known?.coverUrl && known.isbn13 === volume.isbn13)
    return { ...volume, coverUrl: known.coverUrl }
  try {
    const coverUrl = await publishedCoverOf(volume.isbn13)
    return coverUrl ? { ...volume, coverUrl } : volume
  } catch (error) {
    logger.warn('release cover lookup failed', { error, isbn13: volume.isbn13 })
    return volume
  }
}

/** A recording's ASIN kept only once Audible's catalogue answers for it — with
 *  its exact release day and cover, which Audible knows better than the web,
 *  and the ASIN the reader's store sells it under, which the web often gets
 *  from another store. An ASIN Audible does not know is dropped and the volume offered through a
 *  search; one Audible could not be asked about keeps the one confirmed last
 *  time, if any. */
const confirmedOnAudible = async <
  Found extends Pick<FoundVolume, 'asin' | 'title' | 'date' | 'coverUrl'>,
>(
  volume: Found,
  known: Found | undefined,
  language: BookLanguage,
): Promise<Found> => {
  const { asin } = volume
  if (!asin) return volume
  if (asin === known?.asin) return volume
  const product = await audibleProductOf(asin, language)
  if (product === 'unreachable') return { ...volume, asin: known?.asin }
  if (product === 'unknown') {
    logger.warn('Audible ASIN not confirmed', { asin, title: volume.title })
    return { ...volume, asin: undefined }
  }
  return {
    ...volume,
    asin: product.asin,
    date: product.releaseDate ?? volume.date,
    coverUrl: product.coverUrl ?? volume.coverUrl,
  }
}

/** Look one saga up in one language and keep what was found. A saga heard is
 *  judged by Audible's own listing of its series: reached straight from a
 *  recording already known, with no grounded call, else from one the web
 *  search named and Audible confirmed. The web alone decides only when Audible
 *  cannot be reached that way. */
const lookUp = async (
  saga: WatchedSaga,
  previous: SagaWatch | undefined,
  now: Date,
): Promise<SagaWatch> => {
  const today = todayOf(now)
  const audio = formatOf(saga.seriesId) === 'audiobook'
  const known = new Map((previous?.volumes ?? []).map((volume) => [volume.number, volume]))
  const entry = saga.asin ?? previous?.volumes.find((volume) => volume.asin)?.asin
  const direct = audio && entry ? await audibleSeriesOf(entry, saga.language) : undefined
  if (Array.isArray(direct))
    return keepWatch(saga, now, onAudible(direct, previous?.volumes ?? [], today))
  const { value, usage } = await generate<ReleasesOutput>({
    step: 'discovery-releases',
    parts: [{ text: releasesPrompt({ ...saga }, today) }],
    responseSchema: RELEASES_SCHEMA,
    grounded: true,
  })
  await recordUsage(usage)
  const volumes = volumesFrom(value.volumes ?? [])
  const found = audio
    ? await Promise.all(
        volumes.map((volume) =>
          confirmedOnAudible(volume, known.get(volume.number), saga.language),
        ),
      )
    : await datedOnAmazon(volumes.map(withoutAsin), known, saga.language)
  const confirmed = found.find((volume) => volume.asin)?.asin
  const listed =
    audio && confirmed && confirmed !== entry
      ? await audibleSeriesOf(confirmed, saga.language)
      : undefined
  if (Array.isArray(listed))
    return keepWatch(saga, now, onAudible(listed, [...(previous?.volumes ?? []), ...found], today))
  return keepWatch(saga, now, mergedVolumes(previous?.volumes ?? [], found))
}

const keepWatch = async (
  saga: WatchedSaga,
  now: Date,
  volumes: FoundVolume[],
): Promise<SagaWatch> => {
  const watch: SagaWatch = {
    key: watchKeyOf(saga),
    seriesId: saga.seriesId,
    name: saga.name,
    author: saga.author,
    language: saga.language,
    checkedAt: now,
    volumes,
  }
  await DiscoveryCommand.saveWatch(watch)
  return watch
}

/** A printed saga's volumes as Amazon dates them, one page after the other so
 *  Amazon sees a reader browsing rather than a crawler, each with its cover. */
const datedOnAmazon = async (
  volumes: readonly FoundVolume[],
  known: ReadonlyMap<number, FoundVolume>,
  language: BookLanguage,
): Promise<FoundVolume[]> => {
  const dated: FoundVolume[] = []
  for (const volume of volumes)
    dated.push(await withCover(await confirmedOnAmazon(volume, language), known.get(volume.number)))
  return dated
}

/** A printed volume dated as Amazon's page for its ISBN dates it: a book is out
 *  once Amazon sells it, not when the web says another edition came out. An
 *  ISBN Amazon knows no book of in that language is dropped; a page that could
 *  not be read leaves the web's date. */
const confirmedOnAmazon = async <Found extends Pick<FoundVolume, 'isbn13' | 'title' | 'date'>>(
  volume: Found,
  language: BookLanguage,
): Promise<Found> => {
  const { isbn13 } = volume
  if (!isbn13) return volume
  const edition = await amazonEditionOf(isbn13, language)
  if (edition === 'unreachable') return volume
  if (edition === 'unknown') {
    logger.warn('Amazon ISBN not confirmed', { isbn13, title: volume.title })
    return { ...volume, isbn13: undefined }
  }
  return edition.releaseDate ? { ...volume, date: edition.releaseDate } : volume
}

/** A printed saga's volumes are bought in a bookshop: an ASIN the model gave
 *  anyway is not kept. */
const withoutAsin = <Found extends { asin?: unknown }>(volume: Found): Found => ({
  ...volume,
  asin: undefined,
})

// MARK: - The authors

/** How far back an author's works are asked for: enough for the week's
 *  releases, with room for a date the web gets a little wrong. */
const LOOKED_BACK_DAYS = 90

/** Look these authors up on the web, a few side by side, until the budget is
 *  spent, keeping each watch in `watches`. A lookup that fails leaves its
 *  author as they were. */
const lookUpAllAuthors = async (
  authors: readonly WatchedAuthor[],
  watches: Map<string, AuthorWatch>,
  now: Date,
  overBudget: () => boolean,
): Promise<{ watched: number; failed: number; deferred: number }> => {
  let watched = 0
  let failed = 0
  for (let start = 0; start < authors.length; start += CALLS_AT_ONCE) {
    if (overBudget()) return { watched, failed, deferred: authors.length - start }
    const found = await Promise.all(
      authors.slice(start, start + CALLS_AT_ONCE).map(async (author) => {
        try {
          return await lookUpAuthor(author, watches.get(authorWatchKeyOf(author)), now)
        } catch (error) {
          failed += 1
          logger.warn('author release lookup failed', { error, author: authorWatchKeyOf(author) })
          return undefined
        }
      }),
    )
    for (const watch of found) {
      if (!watch) continue
      watched += 1
      watches.set(watch.key, watch)
    }
  }
  return { watched, failed, deferred: 0 }
}

/** Look one author up in one language and format and keep what was found:
 *  a recording kept only once Audible confirms it, a printed book dated as
 *  Amazon dates it and given its cover — as a saga's volumes are. */
const lookUpAuthor = async (
  author: WatchedAuthor,
  previous: AuthorWatch | undefined,
  now: Date,
): Promise<AuthorWatch> => {
  const today = todayOf(now)
  const since = new Date(now.getTime() - LOOKED_BACK_DAYS * 86_400_000).toISOString().slice(0, 10)
  const { value, usage } = await generate<AuthorReleasesOutput>({
    step: 'discovery-author-releases',
    parts: [{ text: authorReleasesPrompt(author, today, since) }],
    responseSchema: AUTHOR_RELEASES_SCHEMA,
    grounded: true,
  })
  await recordUsage(usage)
  const known = new Map((previous?.works ?? []).map((work) => [slugify(work.title), work]))
  const works = worksFrom(value.works ?? [])
  const found: FoundWork[] = []
  // One after the other, as a saga's volumes: Amazon sees a reader browsing.
  for (const work of works) {
    const before = known.get(slugify(work.title))
    found.push(
      author.format === 'audiobook'
        ? await confirmedOnAudible(work, before, author.language)
        : await withCover(await confirmedOnAmazon(withoutAsin(work), author.language), before),
    )
  }
  const watch: AuthorWatch = {
    key: authorWatchKeyOf(author),
    authorKey: author.authorKey,
    name: author.name,
    format: author.format,
    language: author.language,
    checkedAt: now,
    works: mergedWorks(previous?.works ?? [], found, today),
  }
  await DiscoveryCommand.saveAuthorWatch(watch)
  return watch
}
