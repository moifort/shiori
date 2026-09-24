import { AdminCommand } from '~/domain/admin/command'
import { AudibleUseCase } from '~/domain/audible/use-case'
import { BookQuery } from '~/domain/book/query'
import type { BookLanguage } from '~/domain/book/types'
import {
  alertOf,
  audibleTranslationsOf,
  canRefresh,
  datedEditionsOf,
  dueEditions,
  emptyFeed,
  foreignWorksOf,
  ownedInLanguage,
  translationsOf,
  type UnsignedTranslation,
  watchIsStale,
  watchKeyOf,
} from '~/domain/discover/business-rules'
import { DiscoverCommand } from '~/domain/discover/command'
import { editionFrom } from '~/domain/discover/parsing'
import { translationsPrompt } from '~/domain/discover/prompts'
import { DiscoverQuery } from '~/domain/discover/query'
import { TRANSLATIONS_SCHEMA, type TranslationsOutput } from '~/domain/discover/schemas'
import type {
  AudibleTranslations,
  Discover,
  DiscoverFeed,
  ForeignWork,
  Translation,
  TranslationWatch,
} from '~/domain/discover/types'
import { NotificationUseCase } from '~/domain/notification/use-case'
import { generate } from '~/domain/scan/gemini'
import type { AiStepUsage } from '~/domain/scan/types'
import type { Language } from '~/domain/shared/language'
import { BookTitle } from '~/domain/shared/primitives'
import type { AuthorName, UserId } from '~/domain/shared/types'
import { createLogger } from '~/system/logger'
import { objectStore } from '~/system/object-store'
import { withRequestCacheScope } from '~/system/request-cache'
import { optionally } from '~/utils/input'

const logger = createLogger('discover')

/** How many works one call looks up: past ten, the model starts answering the
 *  first ones well and the last ones not at all. */
const WORKS_PER_CALL = 10

/** How many calls one refresh makes, side by side. A library read in English
 *  for years is caught up over a few days rather than in one request the
 *  function would not live through; the most recently read go first. */
const CALLS_PER_REFRESH = 4

/** Two thirds of the function's 180s ceiling, as the Audible sync keeps: the
 *  budget is checked between readers, so a run overshoots by one reader. */
const SCHEDULED_BUDGET_MS = 120_000

const todayOf = (now: Date) => now.toISOString().slice(0, 10)

export namespace DiscoverUseCase {
  /** The tab as the reader opens it: the works they read in another language,
   *  with what the shared watches and their Audible marketplace know of them in
   *  the app's language. Opening it the first time enrols the reader in the
   *  daily refresh. */
  export const discover = async (
    userId: UserId,
    language: Language,
    now = new Date(),
  ): Promise<Discover> => {
    const [stored, books] = await Promise.all([DiscoverQuery.feed(userId), BookQuery.all(userId)])
    const feed = stored ?? (await DiscoverCommand.save(emptyFeed(userId, language)))
    const works = foreignWorksOf(books, feed.language)
    const watches = await watchesOf(works, feed.language)
    const { upcoming, available } = translationsOf(
      works,
      watches,
      feed,
      ownedInLanguage(books, feed.language),
      todayOf(now),
    )
    return {
      preparedAt: feed.refreshedAt,
      canRefresh: canRefresh(feed, now),
      upcoming: await Promise.all(upcoming.map(signed)),
      available: await Promise.all(available.map(signed)),
    }
  }

  /** Look again: the web for the works whose watch is a week old, the reader's
   *  Audible marketplace for all of them. A part that fails keeps what the last
   *  refresh found rather than emptying the tab. */
  export const refresh = async (
    userId: UserId,
    language: Language,
    now = new Date(),
  ): Promise<DiscoverFeed> => {
    const [books, stored] = await Promise.all([BookQuery.all(userId), DiscoverQuery.feed(userId)])
    const previous = stored ?? emptyFeed(userId, language)
    const works = foreignWorksOf(books, language)
    const watches = await trackedWatches(works, language, now)
    const audible = await audibleTranslations(userId, works, watches, language)
    const feed: DiscoverFeed = {
      ...previous,
      language,
      refreshedAt: now,
      audible: audible === 'failed' ? previous.audible : audible,
    }
    const { upcoming, available } = translationsOf(
      works,
      watches,
      feed,
      ownedInLanguage(books, language),
      todayOf(now),
    )
    return DiscoverCommand.save({
      ...feed,
      dated: datedEditionsOf([...upcoming, ...available], todayOf(now)),
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
        logger.warn('translation alerts failed', { error, userId: feed.userId })
      }
    }
    return { readers }
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

const watchesOf = async (
  works: readonly ForeignWork[],
  language: Language,
): Promise<Map<string, TranslationWatch>> =>
  new Map(
    (await DiscoverQuery.watches(works.map((work) => watchKeyOf(work, language)))).map((watch) => [
      watch.key,
      watch,
    ]),
  )

const recordUsage = async (usage: AiStepUsage | undefined) => {
  if (!usage) return
  try {
    await AdminCommand.recordDiscoveryUsage(usage)
  } catch (error) {
    logger.warn('discovery usage not recorded', { error })
  }
}

/** The shared watches of the reader's works, the stale ones looked up again on
 *  the web — a few calls side by side, the most recently read works first. A
 *  call that fails leaves its works as they were. */
const trackedWatches = async (
  works: readonly ForeignWork[],
  language: Language,
  now: Date,
): Promise<Map<string, TranslationWatch>> => {
  const watches = await watchesOf(works, language)
  const stale = works
    .map((work) => ({ key: watchKeyOf(work, language), work }))
    .filter(({ key }) => watchIsStale(watches.get(key), now))
    .slice(0, WORKS_PER_CALL * CALLS_PER_REFRESH)
  const batches = Array.from({ length: Math.ceil(stale.length / WORKS_PER_CALL) }, (_, index) =>
    stale.slice(index * WORKS_PER_CALL, (index + 1) * WORKS_PER_CALL),
  )
  await Promise.all(
    batches.map(async (batch) => {
      try {
        const { value, usage } = await generate<TranslationsOutput>({
          step: 'discover-translations',
          parts: [{ text: translationsPrompt(batch, todayOf(now), language) }],
          responseSchema: TRANSLATIONS_SCHEMA,
          grounded: true,
        })
        await recordUsage(usage)
        const answered = new Map((value.works ?? []).map((entry) => [entry.key, entry]))
        for (const { key, work } of batch) {
          const answer = answered.get(key)
          const watch: TranslationWatch = {
            key,
            kind: work.kind,
            title: work.title,
            author: work.author,
            language,
            checkedAt: now,
            translatedTitle: optionally(answer?.translatedTitle, BookTitle),
            editions: (answer?.editions ?? [])
              .map((raw) => editionFrom(raw, language))
              .filter((edition) => edition !== undefined),
          }
          await DiscoverCommand.saveWatch(watch)
          watches.set(key, watch)
        }
      } catch (error) {
        logger.warn('translation lookup failed', { error, works: batch.length })
      }
    }),
  )
  return watches
}

/** The recordings the reader's Audible marketplace lists for their works.
 *  Undefined for a reader with no Audible connection, `failed` when Amazon
 *  did. */
const audibleTranslations = async (
  userId: UserId,
  works: readonly ForeignWork[],
  watches: ReadonlyMap<string, TranslationWatch>,
  language: Language,
): Promise<DiscoverFeed['audible'] | 'failed'> => {
  const authors = [
    ...new Set(works.flatMap((work) => (work.author ? [work.author] : []))),
  ] as AuthorName[]
  try {
    const found = await AudibleUseCase.recordingsInLanguage(
      userId,
      authors,
      language as BookLanguage,
    )
    if (found === 'not-connected') return undefined
    return {
      marketplace: found.marketplace,
      works: works.flatMap((work): AudibleTranslations[] => {
        const editions = audibleTranslationsOf(
          work,
          watches.get(watchKeyOf(work, language))?.translatedTitle,
          found.recordings,
        )
        return editions.length > 0 ? [{ workKey: work.key, editions }] : []
      }),
    }
  } catch (error) {
    logger.warn('discover Audible lookup failed', { error, userId })
    return 'failed'
  }
}

/** The reader's own photo of their copy is signed only when no translated
 *  edition brought a cover of its own. */
const signed = async ({ coverPath, ...translation }: UnsignedTranslation): Promise<Translation> =>
  coverPath && !translation.coverUrl
    ? { ...translation, coverUrl: await objectStore().downloadUrl(coverPath) }
    : translation
