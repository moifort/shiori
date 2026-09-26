import { AdminCommand } from '~/domain/admin/command'
import { BookQuery } from '~/domain/book/query'
import type { BookLanguage } from '~/domain/book/types'
import {
  alertOf,
  catalogueVolumesOf,
  dueAlertsOf,
  dueWatches,
  formatOf,
  inDiscoveryOrder,
  likelyLanguageOf,
  mergedVolumes,
  readerIsStale,
  releasesOf,
  todayOf,
  watchedSagasOf,
  watchKeyOf,
} from '~/domain/discovery/business-rules'
import { DiscoveryCommand } from '~/domain/discovery/command'
import { audibleProductOf } from '~/domain/discovery/infrastructure/audible-catalogue'
import { volumesFrom } from '~/domain/discovery/parsing'
import { releasesPrompt } from '~/domain/discovery/prompts'
import { DiscoveryQuery } from '~/domain/discovery/query'
import { RELEASES_SCHEMA, type ReleasesOutput } from '~/domain/discovery/schemas'
import type {
  Discovery,
  DiscoveryReader,
  FoundVolume,
  ReleaseFormat,
  SagaDiscovery,
  SagaReleases,
  SagaWatch,
  WatchedSaga,
} from '~/domain/discovery/types'
import { NotificationUseCase } from '~/domain/notification/use-case'
import { generate } from '~/domain/scan/gemini'
import { publishedCoverOf } from '~/domain/scan/published-cover'
import { SeriesCommand } from '~/domain/series/command'
import { SeriesQuery } from '~/domain/series/query'
import type { SeriesId } from '~/domain/series/types'
import { type FollowedSeries, SeriesUseCase } from '~/domain/series/use-case'
import type { Language } from '~/domain/shared/language'
import type { UserId } from '~/domain/shared/types'
import { UserQuery } from '~/domain/user/query'
import { createLogger } from '~/system/logger'
import { withRequestCacheScope } from '~/system/request-cache'

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
  /** The tab as the reader opens it: every saga they follow in that format,
   *  with the volumes out they do not hold and the next one announced, as the
   *  shared watches know them, and how many were never looked up. Opening it
   *  tells the hourly pass at once which sagas the reader follows now, and in
   *  which language to write to them. */
  export const discover = async (
    userId: UserId,
    language: Language,
    format: ReleaseFormat,
    now = new Date(),
  ): Promise<Discovery> => {
    const [followed, reader] = await Promise.all([
      SeriesUseCase.followed(userId),
      DiscoveryQuery.reader(userId),
    ])
    const sagas = watchedSagasOf(followed)
    await rememberReader(userId, sagas, language, reader, now)
    const watches = await DiscoveryQuery.watches(sagas.map(watchKeyOf))
    return discoveryOf(followed, watches, format, now)
  }

  /** The first look at the tab: every saga the reader follows in that format
   *  that was never looked up is looked up now, a few side by side, rather
   *  than on the next hourly pass — within a budget the request lives
   *  through; whatever is left goes to the hourly pass. Answers the tab. */
  export const lookUpUnwatched = async (
    userId: UserId,
    language: Language,
    format: ReleaseFormat,
    now = new Date(),
    budgetMs = ON_DEMAND_BUDGET_MS,
    startedAt = Date.now(),
  ): Promise<Discovery> => {
    const [followed, reader] = await Promise.all([
      SeriesUseCase.followed(userId),
      DiscoveryQuery.reader(userId),
    ])
    const sagas = watchedSagasOf(followed)
    await rememberReader(userId, sagas, language, reader, now)
    const watches = await DiscoveryQuery.watches(sagas.map(watchKeyOf))
    const unwatched = sagas.filter(
      (saga) => formatOf(saga.seriesId) === format && !watches.has(watchKeyOf(saga)),
    )
    await lookUpAll(unwatched, watches, now, () => Date.now() - startedAt > budgetMs)
    return discoveryOf(followed, watches, format, now)
  }

  /** What the saga screen shows under its introduction: the volumes out the
   *  reader does not hold, and the next one announced, in the edition they
   *  opened. Nothing for an edition nobody looked up yet. */
  export const sagaReleases = async (
    userId: UserId,
    seriesId: SeriesId,
    language: BookLanguage,
    now = new Date(),
  ): Promise<SagaReleases> => {
    const [books, watches] = await Promise.all([
      BookQuery.bySeries(userId, seriesId),
      DiscoveryQuery.watches([watchKeyOf({ seriesId, language })]),
    ])
    return releasesOf(
      books.filter((book) => book.language === language),
      watches.get(watchKeyOf({ seriesId, language })),
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
    if (!watches.has(key)) {
      const name = held[0]?.series?.name ?? catalogue?.name
      const author = held[0]?.authors[0] ?? catalogue?.author
      if (name)
        await lookUpAll(
          [{ seriesId, language, name, ...(author ? { author } : {}) }],
          watches,
          now,
          () => false,
        )
    }
    return releasesOf(held, watches.get(key), todayOf(now))
  }

  /** The hourly pass. First every reader whose sagas were last worked out a
   *  day ago has their library read again; then every saga anybody follows
   *  whose watch is a week old is looked up on the web — the ones never looked
   *  up first — and what was found written into its catalogue. Both stop when
   *  the budget is spent; whoever is not reached goes first next hour. */
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
        const followed = await withRequestCacheScope(() => SeriesUseCase.followed(userId))
        const sagas = watchedSagasOf(followed)
        const language = reader?.language ?? likelyLanguageOf(sagas)
        readers.set(userId, await rememberReader(userId, sagas, language, reader, now, true))
        synced += 1
      } catch (error) {
        failed += 1
        logger.warn('discovery reader sync failed', { error, userId })
      }
    }
    const everyone = [...readers.values()]
    const watches = await DiscoveryQuery.watches(
      everyone.flatMap((reader) => reader.sagas.map(watchKeyOf)),
    )
    const due = dueWatches(everyone, watches, now)
    const looked = await lookUpAll(due, watches, now, overBudget)
    return { synced, ...looked, failed: failed + looked.failed }
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
}

// MARK: - The parts of a pass

/** The tab in one format out of the reader's sagas and the watches. */
const discoveryOf = (
  followed: readonly FollowedSeries[],
  watches: ReadonlyMap<string, SagaWatch>,
  format: ReleaseFormat,
  now: Date,
): Discovery => {
  const today = todayOf(now)
  let unwatched = 0
  const rows = followed.flatMap((series): SagaDiscovery[] => {
    if (!series.language || series.state === 'unfollowed') return []
    if (formatOf(series.id) !== format) return []
    const releases = releasesOf(
      series.books,
      watches.get(watchKeyOf({ seriesId: series.id, language: series.language })),
      today,
    )
    if (!releases.watched) unwatched += 1
    return releases.available.length > 0 || releases.next ? [{ ...releases, series }] : []
  })
  return { sagas: inDiscoveryOrder(rows), unwatched }
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
  sagas: WatchedSaga[],
  language: Language,
  known: DiscoveryReader | undefined,
  now: Date,
  force = false,
): Promise<DiscoveryReader> => {
  const unchanged =
    known !== undefined &&
    known.language === language &&
    JSON.stringify(known.sagas) === JSON.stringify(sagas) &&
    !readerIsStale(known, now)
  if (unchanged && !force) return known
  return DiscoveryCommand.saveReader({
    userId,
    language,
    sagas,
    syncedAt: now,
    notified: known?.notified ?? [],
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
const withCover = async (
  volume: FoundVolume,
  known: FoundVolume | undefined,
): Promise<FoundVolume> => {
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
 *  its exact release day and cover, which Audible knows better than the web.
 *  An ASIN Audible does not know is dropped and the volume offered through a
 *  search; one Audible could not be asked about keeps the one confirmed last
 *  time, if any. */
const confirmedOnAudible = async (
  volume: FoundVolume,
  known: FoundVolume | undefined,
  language: BookLanguage,
): Promise<FoundVolume> => {
  const { asin, ...rest } = volume
  if (!asin) return volume
  if (asin === known?.asin) return volume
  const product = await audibleProductOf(asin, language)
  if (product === 'unreachable') return known?.asin ? { ...rest, asin: known.asin } : rest
  if (product === 'unknown') {
    logger.warn('Audible ASIN not confirmed', { asin, title: volume.title })
    return rest
  }
  return {
    ...volume,
    date: product.releaseDate ?? volume.date,
    coverUrl: product.coverUrl ?? volume.coverUrl,
  }
}

/** Look one saga up on the web in one language and keep what was found. */
const lookUp = async (
  saga: WatchedSaga,
  previous: SagaWatch | undefined,
  now: Date,
): Promise<SagaWatch> => {
  const { value, usage } = await generate<ReleasesOutput>({
    step: 'discovery-releases',
    parts: [{ text: releasesPrompt({ ...saga }, todayOf(now)) }],
    responseSchema: RELEASES_SCHEMA,
    grounded: true,
  })
  await recordUsage(usage)
  const known = new Map((previous?.volumes ?? []).map((volume) => [volume.number, volume]))
  const audio = formatOf(saga.seriesId) === 'audiobook'
  const found = await Promise.all(
    volumesFrom(value.volumes ?? []).map((volume) =>
      audio
        ? confirmedOnAudible(volume, known.get(volume.number), saga.language)
        : withCover(withoutAsin(volume), known.get(volume.number)),
    ),
  )
  const watch: SagaWatch = {
    key: watchKeyOf(saga),
    seriesId: saga.seriesId,
    name: saga.name,
    author: saga.author,
    language: saga.language,
    checkedAt: now,
    volumes: mergedVolumes(previous?.volumes ?? [], found),
  }
  await DiscoveryCommand.saveWatch(watch)
  return watch
}

/** A printed saga's volumes are bought in a bookshop: an ASIN the model gave
 *  anyway is not kept. */
const withoutAsin = ({ asin: _, ...volume }: FoundVolume): FoundVolume => volume
