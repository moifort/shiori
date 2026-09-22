import { AdminCommand } from '~/domain/admin/command'
import { AnalyticsUseCase } from '~/domain/analytics/use-case'
import { AudibleUseCase } from '~/domain/audible/use-case'
import { shelfKeyOf, shelfKeysOf } from '~/domain/book/business-rules'
import { BookQuery } from '~/domain/book/query'
import type { Book } from '~/domain/book/types'
import { BookUseCase } from '~/domain/book/use-case'
import {
  alertOf,
  audibleShelvesOf,
  canRefresh,
  dueReleases,
  emptyFeed,
  friendsFavoritesOf,
  GENRE_LIST_EVERY_MS,
  genreListKeyOf,
  REFRESH_EVERY_MS,
  releaseSubjectsOf,
  releasesOf,
  subjectKeyOf,
  type Taste,
  tasteOf,
  unseen,
  watchIsStale,
} from '~/domain/discover/business-rules'
import { DiscoverCommand } from '~/domain/discover/command'
import { suggestionsFrom, watchedReleaseFrom } from '~/domain/discover/parsing'
import { genreListPrompt, personalPrompt, releasesPrompt } from '~/domain/discover/prompts'
import { DiscoverQuery } from '~/domain/discover/query'
import {
  GENRE_LIST_SCHEMA,
  type GenreListOutput,
  PERSONAL_SCHEMA,
  type PersonalOutput,
  RELEASES_SCHEMA,
  type ReleasesOutput,
} from '~/domain/discover/schemas'
import type {
  Discover,
  DiscoverFeed,
  FriendFavorite,
  LovedShelf,
  Release,
  ReleaseSubject,
  ReleaseWatch,
  Suggestion,
} from '~/domain/discover/types'
import { FriendshipQuery } from '~/domain/friendship/query'
import { NotificationUseCase } from '~/domain/notification/use-case'
import { generate } from '~/domain/scan/gemini'
import { publishedCoverOf } from '~/domain/scan/published-cover'
import type { AiStepUsage } from '~/domain/scan/types'
import { seriesKeyOf } from '~/domain/series/primitives'
import type { Language } from '~/domain/shared/language'
import type { UserId } from '~/domain/shared/types'
import { UserQuery } from '~/domain/user/query'
import { createLogger } from '~/system/logger'
import { objectStore } from '~/system/object-store'
import { withRequestCacheScope } from '~/system/request-cache'

const logger = createLogger('discover')

/** How many release subjects one call looks up: past a dozen, the model starts
 *  answering the first ones well and the last ones not at all. */
const SUBJECTS_PER_CALL = 12

/** How many books the personal prompt lists as already known: enough to keep
 *  the obvious out, not so many the prompt is mostly a catalogue. */
const KNOWN_LISTED = 80

/** Two thirds of the function's 180s ceiling, as the Audible sync keeps: the
 *  budget is checked between readers, so a run overshoots by one reader. */
const SCHEDULED_BUDGET_MS = 120_000

const todayOf = (now: Date) => now.toISOString().slice(0, 10)

export namespace DiscoverUseCase {
  /** The tab as the reader opens it: what the last refresh stored, the shared
   *  award and acclaim lists of their genres, and their friends' hearts read
   *  live. Opening it the first time enrols the reader in the weekly refresh. */
  export const discover = async (
    userId: UserId,
    language: Language,
    now = new Date(),
  ): Promise<Discover> => {
    const [stored, ownedKeys, friendIds] = await Promise.all([
      DiscoverQuery.feed(userId),
      BookQuery.shelfKeys(userId),
      FriendshipQuery.friendsOf(userId),
    ])
    const feed = stored ?? (await DiscoverCommand.save(emptyFeed(userId, language)))
    const [shelves, names, lists] = await Promise.all([
      AnalyticsUseCase.sharedShelves(friendIds, now),
      UserQuery.namesOf(friendIds),
      DiscoverQuery.genreLists(feed.genres.map((genre) => genreListKeyOf(genre, feed.language))),
    ])
    const seen = <T extends { key: string }>(items: readonly T[]) =>
      unseen(items, ownedKeys, feed.dismissed)
    return {
      preparedAt: feed.refreshedAt,
      canRefresh: canRefresh(feed, now),
      friendsFavorites: await Promise.all(
        friendsFavoritesOf(shelves, names, ownedKeys, feed.dismissed).map(
          async ({ cover, ...favorite }): Promise<FriendFavorite> => ({
            ...favorite,
            coverUrl: cover.coverPath
              ? await objectStore().downloadUrl(cover.coverPath)
              : cover.publishedCoverUrl,
          }),
        ),
      ),
      audible: seen(feed.audible),
      releases: feed.releases.filter(
        (release) =>
          !ownedKeys.has(shelfKeyOf(release.title, release.authors[0])) &&
          !feed.dismissed.includes(release.key),
      ),
      becauseYouLoved: feed.becauseYouLoved
        .map((shelf) => ({ anchor: shelf.anchor, items: seen(shelf.items) }))
        .filter((shelf) => shelf.items.length > 0),
      awards: seen(lists.flatMap((list) => list.awards)),
      acclaimed: seen(lists.flatMap((list) => list.acclaimed)),
      offTrail: seen(feed.offTrail),
    }
  }

  /** Rebuild the reader's tab: their shelves from the model, the next Audible
   *  recordings of their sagas, the releases of what they follow, and the
   *  shared lists of their genres when those are due. A part that fails keeps
   *  what the last refresh found rather than emptying a shelf. Then any alert
   *  due today goes out. */
  export const refresh = async (
    userId: UserId,
    language: Language,
    now = new Date(),
  ): Promise<DiscoverFeed> => {
    const [books, stored] = await Promise.all([BookQuery.all(userId), DiscoverQuery.feed(userId)])
    const previous = stored ?? emptyFeed(userId, language)
    const taste = tasteOf(books, language)
    const ownedKeys = shelfKeysOf(books)

    const [personal, audible, releases] = await Promise.all([
      personalShelves(taste, books, previous, language),
      audibleShelves(userId, language),
      trackedReleases(taste, ownedKeys, language, now),
      refreshGenreLists(taste, language, now),
    ])

    const feed = await DiscoverCommand.save({
      ...previous,
      language,
      refreshedAt: now,
      audible: audible?.suggestions ?? previous.audible,
      releases: mergedReleases(
        releases ?? previous.releases.filter((r) => r.kind !== 'audible-release'),
        audible?.releases,
      ),
      becauseYouLoved: personal?.becauseYouLoved ?? previous.becauseYouLoved,
      offTrail: personal?.offTrail ?? previous.offTrail,
      genres: taste.genres,
    })
    return sendDueAlerts(feed, now)
  }

  /** The reader asked for a fresh set: granted once a day, otherwise the tab
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

  /** The hourly pass: every reader whose tab is a week old, the oldest first,
   *  until the budget is spent. Whoever is not reached goes first next hour. */
  export const refreshDueReaders = async (
    now = new Date(),
    budgetMs = SCHEDULED_BUDGET_MS,
    startedAt = Date.now(),
  ): Promise<{ refreshed: number; failed: number; deferred: number }> => {
    const due = (await DiscoverQuery.allFeeds())
      .filter(
        (feed) =>
          !feed.refreshedAt || now.getTime() - feed.refreshedAt.getTime() > REFRESH_EVERY_MS,
      )
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

  /** The daily pass: whatever came out today, pushed to whoever wants it. No
   *  model is called; the weekly refresh already knows the dates. */
  export const sendAlertsToEveryReader = async (now = new Date()): Promise<{ readers: number }> => {
    let readers = 0
    for (const feed of await DiscoverQuery.allFeeds()) {
      if (dueReleases(feed.releases, feed.notified, todayOf(now)).length === 0) continue
      try {
        await sendDueAlerts(feed, now)
        readers += 1
      } catch (error) {
        logger.warn('release alerts failed', { error, userId: feed.userId })
      }
    }
    return { readers }
  }

  /** Never propose this book again. */
  export const dismiss = async (userId: UserId, key: string): Promise<boolean> => {
    const feed = await DiscoverQuery.feed(userId)
    if (!feed) return false
    await DiscoverCommand.dismiss(feed, key)
    return true
  }

  /** Put a suggestion on the reader's shelf, from what the tab stored — the
   *  client only names it. */
  export const addSuggestion = async (
    userId: UserId,
    key: string,
    status: 'to-read' | 'read',
  ): Promise<Book | 'not-found' | 'already-owned'> => {
    const feed = await DiscoverQuery.feed(userId)
    if (!feed) return 'not-found'
    const lists = await DiscoverQuery.genreLists(
      feed.genres.map((genre) => genreListKeyOf(genre, feed.language)),
    )
    const suggestion = [
      ...feed.audible,
      ...feed.releases,
      ...feed.offTrail,
      ...feed.becauseYouLoved.flatMap((shelf) => shelf.items),
      ...lists.flatMap((list) => [...list.awards, ...list.acclaimed]),
    ].find((candidate) => candidate.key === key)
    if (!suggestion) return 'not-found'
    const owned = await BookQuery.shelfKeys(userId)
    if (owned.has(shelfKeyOf(suggestion.title, suggestion.authors[0]))) return 'already-owned'
    const author = suggestion.authors[0]
    const book = await BookUseCase.add(userId, {
      title: suggestion.title,
      authors: suggestion.authors,
      format: suggestion.format,
      firstPublishedIn: suggestion.firstPublishedIn,
      synopsis: suggestion.synopsis,
      genre: suggestion.genre,
      isbn13: suggestion.isbn13,
      language: suggestion.language,
      audibleAsin: suggestion.audibleAsin,
      publishedCoverUrl: suggestion.coverUrl,
      series:
        suggestion.series && author
          ? {
              id: seriesKeyOf(suggestion.series.name, author),
              name: suggestion.series.name,
              volume: suggestion.series.volume,
              kind: 'main',
            }
          : undefined,
      status,
    })
    await DiscoverCommand.dismiss(feed, key)
    return book
  }
}

// MARK: - The parts of a refresh

const recordUsage = async (usage: AiStepUsage | undefined) => {
  if (!usage) return
  try {
    await AdminCommand.recordDiscoveryUsage(usage)
  } catch (error) {
    logger.warn('discovery usage not recorded', { error })
  }
}

/** Covers for the suggestions that name an ISBN, looked up once, when stored. */
const withCovers = (suggestions: Suggestion[]): Promise<Suggestion[]> =>
  Promise.all(
    suggestions.map(async (suggestion) =>
      suggestion.coverUrl || !suggestion.isbn13
        ? suggestion
        : { ...suggestion, coverUrl: await publishedCoverOf(suggestion.isbn13) },
    ),
  )

/** "Because you loved" and "Off the beaten path", from the reader's loved
 *  books — or the ones they read last, for a reader who hearted nothing yet.
 *  Undefined when the call failed or there is nothing to go on. */
const personalShelves = async (
  taste: Taste,
  books: readonly Book[],
  feed: DiscoverFeed,
  language: Language,
): Promise<{ becauseYouLoved: LovedShelf[]; offTrail: Suggestion[] } | undefined> => {
  const anchors =
    taste.loved.length > 0
      ? taste.loved
      : books.filter((book) => book.status === 'read').slice(0, 5)
  if (anchors.length === 0) return undefined
  try {
    const { value, usage } = await generate<PersonalOutput>({
      step: 'discover-personal',
      parts: [
        {
          text: personalPrompt({
            loved: anchors,
            genres: taste.genres,
            known: books.slice(0, KNOWN_LISTED),
            dismissed: feed.dismissed.slice(-30),
            language,
          }),
        },
      ],
      responseSchema: PERSONAL_SCHEMA,
      grounded: true,
    })
    await recordUsage(usage)
    const becauseYouLoved = await Promise.all(
      (value.becauseYouLoved ?? []).flatMap((shelf) => {
        const anchor = anchors.find((book) => book.title === shelf.anchor)?.title
        return anchor
          ? [withCovers(suggestionsFrom(shelf.items)).then((items) => ({ anchor, items }))]
          : []
      }),
    )
    return { becauseYouLoved, offTrail: await withCovers(suggestionsFrom(value.offTrail)) }
  } catch (error) {
    logger.warn('discover personal shelves failed', { error })
    return undefined
  }
}

/** The next recordings of the reader's Audible sagas. Undefined for a reader
 *  with no Audible connection, or when Amazon failed. */
const audibleShelves = async (userId: UserId, language: Language) => {
  try {
    const found = await AudibleUseCase.nextInListenedSagas(userId)
    return found === 'not-connected' ? undefined : audibleShelvesOf(found, language)
  } catch (error) {
    logger.warn('discover Audible releases failed', { error, userId })
    return undefined
  }
}

const reasonOf =
  (language: Language) =>
  (subject: ReleaseSubject): string => {
    const fr = language === 'fr'
    switch (subject.kind) {
      case 'series':
        return fr ? `Vous suivez ${subject.name}` : `You follow ${subject.name}`
      case 'author':
        return fr ? `Vous avez adoré ${subject.author}` : `You loved ${subject.author}`
      case 'translation':
        return fr ? 'Vous l’avez lu en version originale' : 'You read it in its original language'
    }
  }

/** The releases of everything the reader follows. Watches are shared: only
 *  the stale ones are looked up, in one call. Undefined when that call failed
 *  and nothing was ever known. */
const trackedReleases = async (
  taste: Taste,
  ownedKeys: ReadonlySet<string>,
  language: Language,
  now: Date,
): Promise<Release[] | undefined> => {
  const subjects = releaseSubjectsOf(taste).map((subject) => ({
    key: subjectKeyOf(subject, language),
    subject,
  }))
  if (subjects.length === 0) return []
  const watches = new Map(
    (await DiscoverQuery.watches(subjects.map(({ key }) => key))).map((watch) => [
      watch.key,
      watch,
    ]),
  )
  const stale = subjects.filter(({ key }) => watchIsStale(watches.get(key), now))
  for (let start = 0; start < stale.length; start += SUBJECTS_PER_CALL) {
    const batch = stale.slice(start, start + SUBJECTS_PER_CALL)
    try {
      const { value, usage } = await generate<ReleasesOutput>({
        step: 'discover-releases',
        parts: [{ text: releasesPrompt(batch, todayOf(now), language) }],
        responseSchema: RELEASES_SCHEMA,
        grounded: true,
      })
      await recordUsage(usage)
      const answered = new Map((value.subjects ?? []).map((entry) => [entry.key, entry.releases]))
      for (const { key, subject } of batch) {
        const watch: ReleaseWatch = {
          key,
          subject,
          checkedAt: now,
          releases: (answered.get(key) ?? [])
            .map(watchedReleaseFrom)
            .filter((r) => r !== undefined),
        }
        await DiscoverCommand.saveWatch(watch)
        watches.set(key, watch)
      }
    } catch (error) {
      logger.warn('discover release lookup failed', { error, subjects: batch.length })
    }
  }
  return releasesOf(
    subjects.flatMap(({ key, subject }) => {
      const watch = watches.get(key)
      return watch ? [{ subject, watch }] : []
    }),
    ownedKeys,
    todayOf(now),
    reasonOf(language),
  )
}

/** Refresh the award and acclaim lists of the reader's genres, when due. */
const refreshGenreLists = async (taste: Taste, language: Language, now: Date): Promise<void> => {
  const keys = taste.genres.map((genre) => genreListKeyOf(genre, language))
  const stored = new Map((await DiscoverQuery.genreLists(keys)).map((list) => [list.key, list]))
  await Promise.all(
    taste.genres.map(async (genre) => {
      const key = genreListKeyOf(genre, language)
      const list = stored.get(key)
      if (list && now.getTime() - list.refreshedAt.getTime() < GENRE_LIST_EVERY_MS) return
      try {
        const { value, usage } = await generate<GenreListOutput>({
          step: 'discover-genre',
          parts: [{ text: genreListPrompt(genre, language) }],
          responseSchema: GENRE_LIST_SCHEMA,
          grounded: true,
        })
        await recordUsage(usage)
        const [awards, acclaimed] = await Promise.all([
          withCovers(suggestionsFrom(value.awards).filter((item) => item.award)),
          withCovers(suggestionsFrom(value.acclaimed)),
        ])
        await DiscoverCommand.saveGenreList({
          key,
          genre,
          language,
          refreshedAt: now,
          awards,
          acclaimed,
        })
      } catch (error) {
        logger.warn('discover genre list failed', { error, genre })
      }
    }),
  )
}

/** The model's releases and Audible's own, one entry per release, the
 *  soonest first. Audible's date wins for a recording both know. */
const mergedReleases = (tracked: readonly Release[], audible: readonly Release[] | undefined) => {
  const byKey = new Map<string, Release>()
  for (const release of [...tracked, ...(audible ?? [])]) byKey.set(release.key, release)
  return [...byKey.values()].sort((left, right) => left.date.localeCompare(right.date))
}

/** Push whatever came out today, and remember it went. */
const sendDueAlerts = async (feed: DiscoverFeed, now: Date): Promise<DiscoverFeed> => {
  const due = dueReleases(feed.releases, feed.notified, todayOf(now))
  if (due.length === 0) return feed
  for (const release of due) {
    try {
      await NotificationUseCase.notify(feed.userId, {
        kind: release.kind,
        ...alertOf(release, feed.language),
        link: 'shiori://discover',
      })
    } catch (error) {
      logger.warn('release alert failed', { error, userId: feed.userId })
    }
  }
  return DiscoverCommand.markNotified(
    feed,
    due.map((release) => release.key),
  )
}
