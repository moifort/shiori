import { AdminCommand } from '~/domain/admin/command'
import { AudibleUseCase } from '~/domain/audible/use-case'
import { BookQuery } from '~/domain/book/query'
import type { Book } from '~/domain/book/types'
import {
  alertOf,
  canRefresh,
  datedEditionsOf,
  dueEditions,
  emptyFeed,
  foundVolumesOf,
  isUpcoming,
  ownedEditionsOf,
  previewIsStale,
  previewKeyOf,
  releasesOf,
  type UnsignedRelease,
  watchedWorksOf,
  watchIsStale,
} from '~/domain/discover/business-rules'
import { DiscoverCommand } from '~/domain/discover/command'
import { editionFrom } from '~/domain/discover/parsing'
import { releasesPrompt } from '~/domain/discover/prompts'
import { DiscoverQuery } from '~/domain/discover/query'
import { RELEASES_SCHEMA, type ReleasesOutput } from '~/domain/discover/schemas'
import type {
  Discover,
  DiscoverFeed,
  Release,
  ReleaseEdition,
  ReleaseWatch,
  WatchedWork,
} from '~/domain/discover/types'
import { NotificationUseCase } from '~/domain/notification/use-case'
import { ScanCommand } from '~/domain/scan/command'
import { generate } from '~/domain/scan/gemini'
import { publishedCoverOf } from '~/domain/scan/published-cover'
import type { AiStepUsage, ScanResult } from '~/domain/scan/types'
import { SeriesCommand } from '~/domain/series/command'
import type { SeriesName } from '~/domain/series/types'
import { type FollowedSeries, SeriesUseCase } from '~/domain/series/use-case'
import type { Language } from '~/domain/shared/language'
import { BookTitle, Count } from '~/domain/shared/primitives'
import type { BookTitle as BookTitleValue, UserId } from '~/domain/shared/types'
import { createLogger } from '~/system/logger'
import { objectStore } from '~/system/object-store'
import { withRequestCacheScope } from '~/system/request-cache'
import { optionally } from '~/utils/input'

const logger = createLogger('discover')

/** One call per work: asked about several at once, the model runs a single
 *  web search for all of them and misses translations that plainly exist. */
const WORKS_PER_REFRESH = 20

/** How many of those calls run side by side. A library read in another
 *  language for years is caught up over a few days rather than in one request
 *  the function would not live through; the most recently read go first. */
const CALLS_AT_ONCE = 5

/** Two thirds of the function's 180s ceiling, as the Audible sync keeps: the
 *  budget is checked between readers, so a run overshoots by one reader. */
const SCHEDULED_BUDGET_MS = 120_000

const todayOf = (now: Date) => now.toISOString().slice(0, 10)

export namespace DiscoverUseCase {
  /** The tab as the reader opens it: what is coming of the sagas they follow,
   *  in the language they read each in and in the app's, and the translations
   *  out of what they read in another language — with what the shared watches
   *  know, recordings only for a reader connected to Audible, looked up now so
   *  a disconnection shows at once. Opening it the first time enrols the
   *  reader in the daily refresh. */
  export const discover = async (
    userId: UserId,
    language: Language,
    now = new Date(),
  ): Promise<Discover> => {
    const [stored, books, followed, marketplace] = await Promise.all([
      DiscoverQuery.feed(userId),
      BookQuery.all(userId),
      SeriesUseCase.followed(userId),
      AudibleUseCase.marketplaceOf(userId),
    ])
    const feed = stored ?? (await DiscoverCommand.save(emptyFeed(userId, language)))
    const works = stillWanted(watchedWorksOf(followed, books, feed.language), feed)
    const watches = await watchesOf(works)
    const { upcoming, maybe } = releasesOf(
      works,
      watches,
      feed,
      marketplace,
      ownedEditionsOf(books),
      todayOf(now),
    )
    const rowOf = sagaRows(followed, watches)
    const served = (release: UnsignedRelease) => signed({ ...release, series: rowOf(release) })
    return {
      preparedAt: feed.refreshedAt,
      canRefresh: canRefresh(feed, now),
      upcoming: await Promise.all(upcoming.map(served)),
      maybe: await Promise.all(maybe.map(served)),
    }
  }

  /** Look again on the web for the works whose watch is a week old, write what
   *  was found of each saga into its catalogue, and keep the exact dates the
   *  alerts go out on. A lookup that fails keeps what the last one found
   *  rather than emptying the tab. */
  export const refresh = async (
    userId: UserId,
    language: Language,
    now = new Date(),
  ): Promise<DiscoverFeed> => {
    const [books, followed, stored, marketplace] = await Promise.all([
      BookQuery.all(userId),
      SeriesUseCase.followed(userId),
      DiscoverQuery.feed(userId),
      AudibleUseCase.marketplaceOf(userId),
    ])
    const previous = stored ?? emptyFeed(userId, language)
    // A work the reader said they are not interested in is never searched
    // again: its call would be paid for a row nobody will see.
    const works = stillWanted(watchedWorksOf(followed, books, language), previous)
    const watches = await trackedWatches(works, now)
    const feed: DiscoverFeed = { ...previous, language, refreshedAt: now }
    const { upcoming, maybe } = releasesOf(
      works,
      watches,
      feed,
      marketplace,
      ownedEditionsOf(books),
      todayOf(now),
    )
    return DiscoverCommand.save({
      ...feed,
      dated: datedEditionsOf([...upcoming, ...maybe], todayOf(now)),
    })
  }

  /** The reader asked for a fresh look: granted once a day, otherwise the tab
   *  as it stands. */
  export const refreshOnDemand = async (
    userId: UserId,
    language: Language,
    now = new Date(),
  ): Promise<Discover> => {
    const feed = await DiscoverQuery.feed(userId)
    if (canRefresh(feed, now)) await refresh(userId, language, now)
    return discover(userId, language, now)
  }

  /** The hourly pass: every reader whose tab is a day old, the oldest first,
   *  until the budget is spent. Whoever is not reached goes first next hour. */
  export const refreshDueReaders = async (
    now = new Date(),
    budgetMs = SCHEDULED_BUDGET_MS,
    startedAt = Date.now(),
  ): Promise<{ refreshed: number; failed: number; deferred: number }> => {
    const due = (await DiscoverQuery.allFeeds())
      .filter((feed) => canRefresh(feed, now))
      .sort(
        (left, right) => (left.refreshedAt?.getTime() ?? 0) - (right.refreshedAt?.getTime() ?? 0),
      )
    let refreshed = 0
    let failed = 0
    for (const [index, feed] of due.entries()) {
      if (Date.now() - startedAt > budgetMs)
        return { refreshed, failed, deferred: due.length - index }
      try {
        await withRequestCacheScope(() => refresh(feed.userId, feed.language, now))
        refreshed += 1
      } catch (error) {
        failed += 1
        logger.warn('discover refresh failed', { error, userId: feed.userId })
      }
    }
    return { refreshed, failed, deferred: 0 }
  }

  /** The daily pass: whatever came out, pushed to whoever wants it. No model
   *  and no library is read; the refresh already kept the dates. */
  export const sendAlertsToEveryReader = async (now = new Date()): Promise<{ readers: number }> => {
    let readers = 0
    for (const feed of await DiscoverQuery.allFeeds()) {
      const due = dueEditions(feed, todayOf(now))
      if (due.length === 0) continue
      try {
        for (const edition of due) {
          await NotificationUseCase.notify(feed.userId, {
            kind: 'translation',
            ...alertOf(edition, feed.language),
            link: 'shiori://discover',
          })
        }
        await DiscoverCommand.markNotified(
          feed,
          due.map((edition) => edition.key),
        )
        readers += 1
      } catch (error) {
        logger.warn('release alerts failed', { error, userId: feed.userId })
      }
    }
    return { readers }
  }

  /** A book the reader does not hold, built whole as a scan builds one —
   *  cover, summary, genre, publisher, pages — so its screen looks like any
   *  book's, even for a book not out yet, described from its announcement.
   *  Shared and kept: the first reader to open it pays the model, nobody else
   *  does, and it spends no scan of anybody's allowance, since the reader is
   *  only looking. Built again once the book is out.
   *
   *  Only for an edition a release watch found — the watch names its author
   *  and date — so a preview is never a free scan of any title. Null for any
   *  other, and when the model failed on a book never built. */
  export const preview = async (
    releaseKey: string,
    title: BookTitleValue,
    language: Language,
    now = new Date(),
  ): Promise<ScanResult | null> => {
    const [watch] = await DiscoverQuery.watches([releaseKey])
    const edition = watch?.editions.find((entry) => entry.title === title)
    if (!watch || !edition) return null
    const key = previewKeyOf(title, watch.author, language)
    const cached = await DiscoverQuery.preview(key)
    if (!previewIsStale(cached, todayOf(now))) return cached?.book ?? null
    try {
      const { result, usage } = await ScanCommand.lookUpTitle(
        BookTitle(watch.author ? `${title} — ${watch.author}` : title),
        language,
      )
      await AdminCommand.recordAiUsage({ cacheHit: false, usage }).catch((error) =>
        logger.warn('AI usage not recorded', { error }),
      )
      const book: ScanResult = {
        ...result,
        title: result.title || title,
        authors: result.authors.length > 0 ? result.authors : watch.author ? [watch.author] : [],
        language: result.language ?? watch.language,
        isbn13: result.isbn13 ?? edition.isbn13,
        coverUrl: result.coverUrl ?? edition.coverUrl,
      }
      const releaseDate =
        edition.date && isUpcoming(edition, todayOf(now)) ? edition.date : undefined
      await DiscoverCommand.savePreview({ key, book, builtAt: now, releaseDate })
      return book
    } catch (error) {
      logger.warn('book preview failed', { error, key })
      return cached?.book ?? null
    }
  }

  /** "Pas intéressé": never propose this work again. */
  export const dismiss = async (userId: UserId, workKey: string): Promise<boolean> => {
    const feed = await DiscoverQuery.feed(userId)
    if (!feed) return false
    await DiscoverCommand.dismiss(feed, workKey)
    return true
  }
}

// MARK: - The parts of a refresh

const stillWanted = (works: readonly WatchedWork[], feed: Pick<DiscoverFeed, 'dismissed'>) => {
  const dismissed = new Set(feed.dismissed)
  return works.filter((work) => !dismissed.has(work.key))
}

const watchesOf = async (works: readonly WatchedWork[]): Promise<Map<string, ReleaseWatch>> =>
  new Map(
    (await DiscoverQuery.watches(works.map((work) => work.key))).map((watch) => [watch.key, watch]),
  )

const recordUsage = async (usage: AiStepUsage | undefined) => {
  if (!usage) return
  try {
    await AdminCommand.recordDiscoveryUsage(usage)
  } catch (error) {
    logger.warn('discovery usage not recorded', { error })
  }
}

/** Each printed edition's cover, found by its ISBN. One that cannot be found
 *  goes without, as it would on a book. */
const withCovers = (editions: readonly ReleaseEdition[]): Promise<ReleaseEdition[]> =>
  Promise.all(
    editions.map(async (edition) => {
      if (edition.format !== 'book' || !edition.isbn13) return edition
      try {
        const coverUrl = await publishedCoverOf(edition.isbn13)
        return coverUrl ? { ...edition, coverUrl } : edition
      } catch (error) {
        logger.warn('release cover lookup failed', { error, isbn13: edition.isbn13 })
        return edition
      }
    }),
  )

/** The shared watches of the reader's works, the stale ones looked up again on
 *  the web — one call per work, a few side by side, the most recently read
 *  first — and what each saga's search found written into its catalogue, so
 *  the series screen, the saga's state and the dashboard follow. A call that
 *  fails leaves its work as it was. */
const trackedWatches = async (
  works: readonly WatchedWork[],
  now: Date,
): Promise<Map<string, ReleaseWatch>> => {
  const watches = await watchesOf(works)
  const stale = works
    .filter((work) => watchIsStale(watches.get(work.key), now))
    .slice(0, WORKS_PER_REFRESH)
  const found: { work: WatchedWork; watch: ReleaseWatch }[] = []
  for (let start = 0; start < stale.length; start += CALLS_AT_ONCE) {
    await Promise.all(
      stale.slice(start, start + CALLS_AT_ONCE).map(async (work) => {
        try {
          const { value, usage } = await generate<ReleasesOutput>({
            step: 'discover-releases',
            parts: [{ text: releasesPrompt(work, todayOf(now)) }],
            responseSchema: RELEASES_SCHEMA,
            grounded: true,
          })
          await recordUsage(usage)
          const answer = (value.works ?? []).find((entry) => entry.key === work.key)
          const watch: ReleaseWatch = {
            key: work.key,
            kind: work.kind,
            title: work.title,
            author: work.author,
            language: work.language,
            checkedAt: now,
            localTitle: optionally(answer?.translatedTitle, BookTitle),
            editions: await withCovers(
              (answer?.editions ?? [])
                .map((raw) => editionFrom(raw, work.language))
                .filter((edition) => edition !== undefined),
            ),
          }
          await DiscoverCommand.saveWatch(watch)
          watches.set(work.key, watch)
          found.push({ work, watch })
        } catch (error) {
          logger.warn('release lookup failed', { error, work: work.key })
        }
      }),
    )
  }
  // One after the other: a saga searched in two languages side by side would
  // otherwise have each write overwrite the other's from the same stale read.
  for (const { work, watch } of found) {
    if (!work.seriesId) continue
    try {
      await SeriesCommand.recordReleases(work.seriesId, work.language, foundVolumesOf(watch))
    } catch (error) {
      logger.warn('release dates not recorded', { error, work: work.key })
    }
  }
  return watches
}

/** A saga's row as the Series tab draws it, in the language of the release:
 *  the reader's own row when they hold that edition; otherwise a row with no
 *  books of its own, named as that language names the saga, measured on the
 *  same catalogue. */
const sagaRows =
  (followed: readonly FollowedSeries[], watches: ReadonlyMap<string, ReleaseWatch>) =>
  (release: UnsignedRelease): FollowedSeries | undefined => {
    if (release.kind !== 'series' || !release.seriesId) return undefined
    const rows = followed.filter((row) => row.id === release.seriesId)
    const own = rows.find((row) => row.language === release.language)
    if (own) return own
    const any = rows[0]
    if (!any) return undefined
    const localTitle = watches.get(release.key)?.localTitle
    return {
      ...any,
      name: (localTitle ?? any.name) as unknown as SeriesName,
      language: release.language,
      state: null,
      progress: null,
      ownedCount: Count(0),
      books: [] as Book[],
    }
  }

/** The reader's own photo of their copy is signed only when no edition
 *  brought a cover of its own. */
const signed = async ({ coverPath, ...release }: UnsignedRelease): Promise<Release> =>
  coverPath && !release.coverUrl
    ? { ...release, coverUrl: await objectStore().downloadUrl(coverPath) }
    : release
