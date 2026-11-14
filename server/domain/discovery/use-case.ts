import type { AuthorKey, ShelvedAuthor } from '~/domain/author/types'
import { AuthorUseCase } from '~/domain/author/use-case'
import { awaitedByAuthorOf, viewOf } from '~/domain/awaited-edition/business-rules'
import { AwaitedEditionQuery } from '~/domain/awaited-edition/query'
import type { AwaitedEditionView } from '~/domain/awaited-edition/types'
import { BookQuery } from '~/domain/book/query'
import type { Book, BookLanguage } from '~/domain/book/types'
import {
  type Announcement,
  AUTHOR_WATCH_EVERY_MS,
  alertOf,
  announcedEditionOf,
  announcedPreviewOf,
  authorReleasesOf,
  authorWatchKeyOf,
  catalogueVolumesOf,
  digestOf,
  dueAlertsOf,
  dueAuthorWatches,
  dueNarratorWatches,
  dueWatches,
  dueWorkAlertsOf,
  followedKeysOf,
  followingOnly,
  formatOf,
  inAnnouncementOrder,
  inDiscoveryOrder,
  isDiscoverable,
  isFollowedAuthor,
  isProjectionFresh,
  likelyLanguageOf,
  looksLeftToday,
  mayBeBehindOf,
  missingVolumesOf,
  NARRATOR_WATCH_EVERY_MS,
  NO_WORK_CONTEXT,
  narratorWatchKeyOf,
  newAnnouncementsOf,
  newWorkAnnouncementsOf,
  possiblyUnwatchedOf,
  projectionsToRefreshOf,
  readerIsStale,
  readersFollowingOf,
  recentReleasesOf,
  releaseFormatOf,
  releasesOf,
  sagasByAuthorOf,
  sagasToListOnAudible,
  shownVolumeOf,
  todayOf,
  volumeIdentityOf,
  volumeShownOf,
  WATCH_EVERY_MS,
  type WorkContext,
  watchedAuthorsOf,
  watchedNarratorsOf,
  watchedSagasOf,
  watchKeyOf,
  workAlertOf,
  yearVolumesOf,
} from '~/domain/discovery/business-rules'
import { DiscoveryCommand } from '~/domain/discovery/command'
import {
  audibleEditionOf,
  audibleRecordingOf,
} from '~/domain/discovery/infrastructure/audible-catalogue'
import { DiscoveryQuery } from '~/domain/discovery/query'
import type {
  AnnouncedVolumePreview,
  AudibleRecording,
  AuthorDiscovery,
  AuthorReleases,
  AuthorWatch,
  Discovery,
  DiscoveryPassState,
  DiscoveryProjection,
  DiscoveryReader,
  FoundVolume,
  ReleaseDescription,
  ReleaseFormat,
  ReleaseSeed,
  SagaDiscovery,
  SagaReleases,
  SagaWatch,
  WatchedAuthor,
  WatchedNarrator,
  WatchedSaga,
} from '~/domain/discovery/types'
import {
  CALLS_AT_ONCE,
  confirmedOnAmazon,
  confirmedOnAudible,
  listedOnAudible,
  lookUpAll,
  lookUpAllAuthors,
  lookUpAllNarrators,
  withCover,
  withoutAsin,
} from '~/domain/discovery/web-lookups'
import { shelvedNarratorsOf } from '~/domain/narrator/business-rules'
import { NarratorQuery } from '~/domain/narrator/query'
import { NotificationUseCase } from '~/domain/notification/use-case'
import { releaseKeyOf } from '~/domain/release/business-rules'
import { ReleaseQuery } from '~/domain/release/query'
import type { ReleaseView } from '~/domain/release/types'
import { type DescribeRefusal, ReleaseUseCase } from '~/domain/release/use-case'
import type { ScanResult } from '~/domain/scan/types'
import { type ScanOutcome, ScanUseCase } from '~/domain/scan/use-case'
import { SeriesCommand } from '~/domain/series/command'
import { SeriesQuery } from '~/domain/series/query'
import type { SagaKey, VolumeNumber } from '~/domain/series/types'
import { type FollowedSeries, SeriesUseCase } from '~/domain/series/use-case'
import { SeriesOpinionQuery } from '~/domain/series-opinion/query'
import type { Language } from '~/domain/shared/language'
import type { AuthorName, BookTitle, UserId } from '~/domain/shared/types'
import { UserQuery } from '~/domain/user/query'
import { createLogger } from '~/system/logger'
import { withRequestCacheScope } from '~/system/request-cache'
import { slugify } from '~/utils/slug'

const logger = createLogger('discovery')

/** How many sagas one Audible sync lists from Audible: a few seconds of a
 *  reader's sync, and a large library imported long ago is listed over a few
 *  nights rather than in one. */
const MAX_LISTED_PER_SYNC = 20

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

  /** A recording the web named, kept as the release watches keep theirs: its
   *  ASIN only once Audible's catalogue answers for it, with Audible's release
   *  day and cover. */
  export const confirmedRecording = <
    Found extends Pick<FoundVolume, 'asin' | 'title' | 'date' | 'coverUrl'>,
  >(
    found: Found,
    known: Found | undefined,
    language: BookLanguage,
  ): Promise<Found> => confirmedOnAudible(found, known, language)

  /** A printed edition the web named, kept as the release watches keep theirs:
   *  dated as Amazon dates its ISBN, an ISBN Amazon does not know dropped, and
   *  given its publisher's cover. */
  export const confirmedPrinting = async <
    Found extends Pick<FoundVolume, 'asin' | 'isbn13' | 'title' | 'date' | 'coverUrl'>,
  >(
    found: Found,
    known: Found | undefined,
    language: BookLanguage,
  ): Promise<Found> => withCover(await confirmedOnAmazon(withoutAsin(found), language), known)

  /** The tab as the reader opens it: every saga they follow in that format
   *  with a volume announced they do not hold or one just out, and every
   *  author they hold in that format with a work announced or just out outside
   *  those sagas, as the shared watches know them, and how many were never
   *  looked up. An author the reader awaits an edition of in that format,
   *  announced or out, is on the Authors shelf with it, even one they hold
   *  only in the other. Opening it tells the hourly pass at once which sagas
   *  and authors the reader follows now, and in which language to write to
   *  them. */
  export const discover = async (
    userId: UserId,
    language: Language,
    format: ReleaseFormat,
    now = new Date(),
  ): Promise<Discovery> => {
    const [projection, change] = await Promise.all([
      DiscoveryQuery.projection(userId, format),
      DiscoveryQuery.libraryChange(userId),
    ])
    if (projection && isProjectionFresh(projection, change, language, todayOf(now)))
      return projection.discovery
    return projectDiscovery(userId, language, format, now)
  }

  /** What came out since the start of the year for the reader: the volumes of
   *  the sagas they follow, and the editions they await that are out. Read off
   *  the shared watches: no web lookup. */
  export const yearReleases = async (userId: UserId, now = new Date()) => {
    const [library, awaited] = await Promise.all([libraryOf(userId), awaitedOf(userId, now)])
    const watches = await DiscoveryQuery.watches(library.sagas.map(watchKeyOf))
    const today = todayOf(now)
    const volumes = library.followed.filter(isDiscoverable).flatMap((series) => {
      const watch = watches.get(watchKeyOf({ seriesId: series.saga, language: series.language }))
      if (!watch) return []
      const format = formatOf(series.saga)
      return yearVolumesOf(watch, series.catalogue, today).map((volume) => ({
        series,
        volume,
        format,
      }))
    })
    return { volumes, awaited, today }
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
    const [library, awaited] = await Promise.all([libraryOf(userId), awaitedOf(userId, now)])
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
    const discovery = await discoveryOf(library, watches, authorWatches, awaited, format, now)
    await keepProjection({ userId, format, language, day: todayOf(now), builtAt: now, discovery })
    return discovery
  }

  /** What the saga screen shows under its introduction: the next volume
   *  announced the reader does not hold, in the edition they opened. Nothing
   *  for an edition nobody looked up yet. */
  export const sagaReleases = async (
    userId: UserId,
    sagaKey: SagaKey,
    language: BookLanguage,
    now = new Date(),
  ): Promise<SagaReleases> => {
    const [books, watches, catalogue] = await Promise.all([
      BookQuery.bySaga(userId, sagaKey),
      DiscoveryQuery.watches([watchKeyOf({ seriesId: sagaKey, language })]),
      SeriesQuery.byId({ saga: sagaKey, language }),
    ])
    return releasesOf(
      books.filter((book) => book.language === language),
      watches.get(watchKeyOf({ seriesId: sagaKey, language })),
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
    sagaKey: SagaKey,
    language: BookLanguage,
    now = new Date(),
  ): Promise<SagaReleases> => {
    const key = watchKeyOf({ seriesId: sagaKey, language })
    const [books, watches, catalogue] = await Promise.all([
      BookQuery.bySaga(userId, sagaKey),
      DiscoveryQuery.watches([key]),
      SeriesQuery.byId({ saga: sagaKey, language }),
    ])
    const held = books.filter((book) => book.language === language)
    const lookingUp = !watches.has(key)
    if (lookingUp) {
      const name = held[0]?.series?.name ?? catalogue?.name
      const author = held[0]?.authors[0] ?? catalogue?.author
      const asin = held.find((book) => book.audibleAsin)?.audibleAsin
      if (name)
        await lookUpAll(
          [
            {
              seriesId: sagaKey,
              language,
              name,
              ...(author ? { author } : {}),
              ...(asin ? { asin } : {}),
            },
          ],
          watches,
          now,
          () => false,
        )
    }
    // The catalogue as the lookup left it, the dates it found written in.
    const written =
      lookingUp && watches.has(key)
        ? await SeriesQuery.byId({ saga: sagaKey, language })
        : catalogue
    return releasesOf(held, watches.get(key), written, todayOf(now))
  }

  /** The sagas an Audible sync holds recordings of, listed straight from
   *  Audible's own listing of each series: every volume, with its release day
   *  and cover, written into the watch and into the saga's catalogue, so the
   *  saga screen draws the covers of the volumes the reader does not hold
   *  without waiting for the hourly pass. A few calls to Audible's public
   *  catalogue per saga, and no grounded one.
   *
   *  Each saga is asked once (`sagasToListOnAudible`), the ones never looked up
   *  first, `MAX_LISTED_PER_SYNC` at a time: a library imported long ago is
   *  listed over a few nights. A saga Audible files under no series keeps its
   *  watch as it stands, marked as asked; one Audible could not be asked about
   *  is asked on the next sync. Never throws: covers are no reason to fail a
   *  sync. */
  export const listOnAudible = async (
    sagas: readonly WatchedSaga[],
    now = new Date(),
  ): Promise<{ listed: number; left: number }> => {
    if (sagas.length === 0) return { listed: 0, left: 0 }
    try {
      const watches = await DiscoveryQuery.watches(sagas.map(watchKeyOf))
      const due = sagasToListOnAudible(sagas, watches)
      let listed = 0
      for (
        let start = 0;
        start < Math.min(due.length, MAX_LISTED_PER_SYNC);
        start += CALLS_AT_ONCE
      ) {
        const end = Math.min(start + CALLS_AT_ONCE, MAX_LISTED_PER_SYNC)
        const asked = await Promise.all(
          due.slice(start, end).map(async (saga) => {
            try {
              return await listedOnAudible(saga, watches.get(watchKeyOf(saga)), now)
            } catch (error) {
              logger.warn('Audible series listing failed', { error, saga: watchKeyOf(saga) })
              return undefined
            }
          }),
        )
        // One after the other, as the hourly pass writes them.
        for (const watch of asked) {
          if (!watch) continue
          listed += 1
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
      return { listed, left: Math.max(0, due.length - MAX_LISTED_PER_SYNC) }
    } catch (error) {
      logger.warn('Audible series listing failed', { error })
      return { listed: 0, left: 0 }
    }
  }

  /** What the author's page shows under its heading: the soonest work
   *  announced and the ones out in the last three months, in that format,
   *  outside the sagas the reader holds, and the editions of theirs the
   *  reader awaits in it that are announced or out — as the Authors shelf of
   *  the tab shows them. No work found for an author the reader holds nothing
   *  of in that format, nor one never looked up: the hourly pass will. */
  export const authorReleases = async (
    userId: UserId,
    authorKey: AuthorKey,
    format: ReleaseFormat,
    now = new Date(),
  ): Promise<AuthorReleases> => {
    const [authors, awaitedViews] = await Promise.all([
      AuthorUseCase.shelvedAuthors(userId),
      awaitedOf(userId, now),
    ])
    const shelved = authors.find((author) => author.key === authorKey)
    if (!shelved) return { recent: [], awaited: [] }
    const awaited = awaitedByAuthorOf(awaitedViews, format, shelved.books).get(authorKey) ?? []
    const watched = watchedAuthorsOf([shelved]).find((author) => author.format === format)
    if (!watched) return { recent: [], awaited }
    const key = authorWatchKeyOf(watched)
    const [watches, sagas] = await Promise.all([
      DiscoveryQuery.authorWatches([key]),
      SeriesUseCase.followedAmong(userId, new Set(shelved.seriesIds)),
    ])
    const sagaNames = new Set([
      ...sagas.map((series) => slugify(series.name)),
      ...shelved.books.flatMap((book) => (book.series ? [slugify(book.series.name)] : [])),
    ])
    const releases = authorReleasesOf(
      shelved.books,
      sagaNames,
      watches.get(key),
      todayOf(now),
      titlesOf(awaited),
    )
    return { ...releases, awaited }
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
    { saga, language, number }: { saga: SagaKey; language: BookLanguage; number: VolumeNumber },
    appLanguage: Language,
  ): Promise<AnnouncedVolumePreview | 'not-found' | Exclude<ScanOutcome, ScanResult>> => {
    const key = watchKeyOf({ seriesId: saga, language })
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
    if (typeof described === 'string' || 'failed' in described) return described
    return announcedPreviewOf(watch, volume, recording, described)
  }

  /** Describe one volume a saga's watch announced for its page, as its
   *  release: `not-found` for a volume no watch announced in that edition. */
  export const describeVolume = async (
    userId: UserId,
    { saga, language, number }: { saga: SagaKey; language: BookLanguage; number: VolumeNumber },
    appLanguage: Language,
    now = new Date(),
  ): Promise<ReleaseView | DescribeRefusal | 'not-found'> => {
    const key = watchKeyOf({ seriesId: saga, language })
    const watch = (await DiscoveryQuery.watches([key])).get(key)
    const volume = watch?.volumes.find((found) => found.number === number)
    if (!watch || !volume) return 'not-found'
    const shown = shownVolumeOf(watch, volume)
    return ReleaseUseCase.describeShown(
      userId,
      volumeIdentityOf(shown),
      volumeShownOf(shown, todayOf(now)),
      appLanguage,
      now,
    )
  }

  /** Describe a book Découvrir shows — a saga's volume, an edition awaited,
   *  an award winner — for its page, as a scan describes a book: the grounded
   *  model fills in its summary, genre, pages and publisher, and Audible its
   *  narrators and running time for a recording. Kept for every reader who
   *  opens the same book in the same language, so the call is paid once and
   *  spends nobody's scan; a reader whose allowance is used up is refused one
   *  nobody described yet, and keeps the plain page. */
  export const describeRelease = async (
    userId: UserId,
    seed: ReleaseSeed,
    appLanguage: Language,
    now = new Date(),
  ): Promise<ReleaseDescription | Exclude<ScanOutcome, ScanResult>> => {
    const format = releaseFormatOf(seed.format)
    const language = seed.language ?? appLanguage
    const release = await ReleaseUseCase.describe(
      userId,
      {
        key: releaseKeyOf(seed.title, seed.authors[0], format, language),
        title: seed.title,
        ...(seed.authors[0] ? { author: seed.authors[0] } : {}),
        originalLanguage: language,
        ...(seed.series
          ? {
              series: {
                name: seed.series.name,
                ...(seed.series.volume !== undefined ? { volume: seed.series.volume } : {}),
              },
            }
          : {}),
        format,
        language,
      },
      seed,
      appLanguage,
      now,
    )
    if (typeof release === 'string' || 'failed' in release) return release
    const kept = release.descriptions?.[appLanguage]
    if (!kept) throw new Error('A release just described holds no description')
    return kept.description
  }

  /** The hourly pass. First every reader whose sagas and authors were last
   *  worked out a day ago has their library read again, and every reader whose
   *  account is gone forgotten; then every saga anybody follows that is due —
   *  two weeks old with news, two months quiet, or held further than its last
   *  look found — is looked up on the web, the ones never looked up first, and
   *  what was found written into its catalogue; then every author, the same
   *  way. No more than `MAX_LOOKS_PER_DAY` in a day, and all stop when the
   *  budget is spent; whatever is not reached goes first next time. */
  export const watchDueSagas = async (
    now = new Date(),
    budgetMs = SCHEDULED_BUDGET_MS,
    startedAt = Date.now(),
  ): Promise<{
    synced: number
    watched: number
    failed: number
    deferred: number
    /** The readers following a saga or an author looked up: their tab changed. */
    changedReaders: UserId[]
  }> => {
    const overBudget = () => Date.now() - startedAt > budgetMs
    const [userIds, stored] = await Promise.all([UserQuery.allIds(), DiscoveryQuery.allReaders()])
    const readers = new Map(await withoutAccountsGone(stored, userIds))
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
    const pass = await watchesForThePass([...readers.values()], now)
    const { watches, authorWatches, narratorWatches } = pass
    // The lookups replace the watches they write in these maps: what differs
    // from this copy afterwards is what changed.
    const sagasBefore = new Map(watches)
    const authorsBefore = new Map(authorWatches)
    // The day's looks are shared: sagas first, then authors, then narrators,
    // whatever is left waiting for the next day.
    const left = looksLeftToday(
      [...watches.values(), ...authorWatches.values(), ...narratorWatches.values()],
      now,
    )
    const dueSagas = dueWatches(pass.readers, watches, now)
    const sagas = await lookUpAll(dueSagas.slice(0, left), watches, now, overBudget)
    const dueAuthors = dueAuthorWatches(pass.readers, authorWatches, now)
    const authorsLeft = Math.max(0, left - Math.min(left, dueSagas.length))
    // The credit the sagas found spent is spent for the authors too: they wait
    // for next hour, as on a spent budget.
    const authors = await lookUpAllAuthors(
      dueAuthors.slice(0, authorsLeft),
      authorWatches,
      now,
      sagas.refused ? () => true : overBudget,
    )
    const dueNarrators = dueNarratorWatches(pass.readers, narratorWatches, now)
    const narratorsLeft = Math.max(0, authorsLeft - Math.min(authorsLeft, dueAuthors.length))
    const narrators = await lookUpAllNarrators(
      dueNarrators.slice(0, narratorsLeft),
      narratorWatches,
      now,
      sagas.refused ? () => true : overBudget,
    )
    const capped =
      Math.max(0, dueSagas.length - left) +
      Math.max(0, dueAuthors.length - authorsLeft) +
      Math.max(0, dueNarrators.length - narratorsLeft)
    // Best effort: without it, the next pass reads every watch followed.
    await DiscoveryCommand.savePassState(pass.stateAfter()).catch((error) =>
      logger.warn('discovery pass state not saved', { error }),
    )
    const changedOf = <T>(after: ReadonlyMap<string, T>, before: ReadonlyMap<string, T>) =>
      new Set([...after].filter(([key, watch]) => before.get(key) !== watch).map(([key]) => key))
    return {
      synced,
      watched: sagas.watched + authors.watched + narrators.watched,
      failed: failed + sagas.failed + authors.failed + narrators.failed,
      deferred: sagas.deferred + authors.deferred + narrators.deferred + capped,
      changedReaders: readersFollowingOf(
        pass.readers,
        changedOf(watches, sagasBefore),
        changedOf(authorWatches, authorsBefore),
      ),
    }
  }

  /** The hourly pass's last step: the projections of the readers whose tab
   *  changed are marked stale, then every stale projection of a reader who
   *  opened the tab lately is worked out again, the new day's included, so
   *  their next opening reads it at once. What the budget leaves is worked out
   *  at the opening. */
  export const refreshProjections = async (
    changedReaders: readonly UserId[],
    now = new Date(),
    budgetMs = SCHEDULED_BUDGET_MS,
    startedAt = Date.now(),
  ): Promise<{ refreshed: number; failed: number; deferred: number }> => {
    // Dated like the rewrites below, which start no earlier: they make it fresh.
    if (changedReaders.length > 0) await DiscoveryCommand.recordLibraryChange(changedReaders, now)
    const states = await DiscoveryQuery.projectionStates()
    const changes = await DiscoveryQuery.libraryChanges(states.map((state) => state.userId))
    const due = projectionsToRefreshOf(states, changes, now)
    let refreshed = 0
    let failed = 0
    for (const [index, state] of due.entries()) {
      if (Date.now() - startedAt > budgetMs)
        return { refreshed, failed, deferred: due.length - index }
      try {
        await withRequestCacheScope(() =>
          projectDiscovery(state.userId, state.language, state.format, now),
        )
        refreshed += 1
      } catch (error) {
        failed += 1
        logger.warn('discovery projection not refreshed', { error, userId: state.userId })
      }
    }
    return { refreshed, failed, deferred: 0 }
  }

  /** The morning pass: every volume that came out, pushed to the readers who
   *  follow its saga, and every work out by an author they hold or read by a
   *  narrator they follow, once. No model is called; the hourly pass already
   *  knows the dates. A reader's books are read only when one of their
   *  authors or narrators has something out. */
  export const sendAlertsToEveryReader = async (now = new Date()): Promise<{ readers: number }> => {
    const readers = await DiscoveryQuery.allReaders()
    const [watches, authorWatches, narratorWatches] = await everyWatchOf(readers)
    const today = todayOf(now)
    let reached = 0
    for (const reader of readers) {
      try {
        const volumes = dueAlertsOf(reader, watches, today)
        const unread = dueWorkAlertsOf(
          reader,
          authorWatches,
          narratorWatches,
          NO_WORK_CONTEXT,
          today,
        )
        const works =
          unread.length === 0
            ? []
            : dueWorkAlertsOf(
                reader,
                authorWatches,
                narratorWatches,
                // In a scope of its own, as the digest reads it: the reader's
                // library is not kept in memory until the pass ends.
                await withRequestCacheScope(() => workContextOf(reader.userId, now)),
                today,
              )
        const due = [
          ...volumes.map((alert) => ({ key: alert.key, ...alertOf(alert, reader.language) })),
          ...works.map((release) => ({
            key: release.key,
            ...workAlertOf(release, reader.language),
          })),
        ]
        if (due.length === 0) continue
        // A release no device heard stays due: the reader may register one
        // before its two weeks are up.
        const settled: string[] = []
        for (const { key, title, body } of due) {
          const delivery = await NotificationUseCase.notify(reader.userId, {
            kind: 'translation',
            title,
            body,
            link: 'shiori://discover',
          })
          if (delivery !== 'undelivered') settled.push(key)
        }
        if (settled.length === 0) continue
        await DiscoveryCommand.markNotified(reader.userId, settled)
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
    const [watches, authorWatches, narratorWatches] = await everyWatchOf(readers)
    const today = todayOf(now)
    let reached = 0
    for (const reader of readers) {
      try {
        const announced = new Set(reader.announced ?? [])
        const [followed, context, editions] = await withRequestCacheScope(() =>
          Promise.all([
            SeriesUseCase.followed(reader.userId),
            workContextOf(reader.userId, now),
            announcedEditionsOf(reader.userId, now),
          ]),
        )
        const due = inAnnouncementOrder([
          ...newAnnouncementsOf(followed, watches, announced, today),
          ...newWorkAnnouncementsOf(
            reader,
            authorWatches,
            narratorWatches,
            context,
            announced,
            today,
          ),
          ...editions.filter(({ key }) => !announced.has(key)),
        ])
        // Nothing new this week: no notification.
        if (due.length === 0) continue
        const delivery = await NotificationUseCase.notify(reader.userId, {
          kind: 'digest',
          ...digestOf(due, reader.language, today),
          link: 'shiori://discover',
        })
        // Named to no device, the volumes wait for next Sunday's digest.
        if (delivery === 'undelivered') continue
        await DiscoveryCommand.markAnnounced(
          reader.userId,
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

/** Every watch the readers' alerts and digests are worked out from: their
 *  sagas', their authors' and their narrators', each in one getAll. */
const everyWatchOf = (readers: readonly DiscoveryReader[]) =>
  Promise.all([
    DiscoveryQuery.watches(readers.flatMap((reader) => reader.sagas.map(watchKeyOf))),
    DiscoveryQuery.authorWatches(
      readers.flatMap((reader) => (reader.authors ?? []).map(authorWatchKeyOf)),
    ),
    DiscoveryQuery.narratorWatches(
      readers.flatMap((reader) => (reader.narrators ?? []).map(narratorWatchKeyOf)),
    ),
  ])

/** What a reader holds and awaits, folded, to tell a work they care for from
 *  one named by another alert. */
const workContextOf = async (userId: UserId, now: Date): Promise<WorkContext> => {
  const [books, awaited] = await Promise.all([BookQuery.all(userId), awaitedOf(userId, now)])
  const titlesIn = (format: ReleaseFormat) =>
    new Set(
      books
        .filter((book) => releaseFormatOf(book.format) === format)
        .map((book) => slugify(book.title)),
    )
  return {
    sagaNames: new Set(books.flatMap((book) => (book.series ? [slugify(book.series.name)] : []))),
    heldTitles: { book: titlesIn('book'), audiobook: titlesIn('audiobook') },
    awaitedTitles: new Set(
      awaited.flatMap((view) => [
        slugify(view.source.title),
        ...(view.found ? [slugify(view.found.title)] : []),
      ]),
    ),
  }
}

/** The editions the reader awaits that are announced for a known date and
 *  still to come, as the digest names them. */
const announcedEditionsOf = async (userId: UserId, now: Date): Promise<Announcement[]> =>
  (await awaitedOf(userId, now)).flatMap((view): Announcement[] => {
    const date = view.found?.date
    if (view.state !== 'announced' || !date) return []
    const author = view.source.authors[0]
    return [
      {
        key: `edition--${view.watchKey}`,
        date,
        kind: 'edition',
        title: view.found?.title ?? view.source.title,
        ...(author ? { author } : {}),
      },
    ]
  })

/** What the tab is worked out from: the reader's sagas and authors, and which
 *  of them are watched. */
type Library = {
  followed: FollowedSeries[]
  shelved: ShelvedAuthor<Book>[]
  sagas: WatchedSaga[]
  authors: WatchedAuthor[]
  narrators: WatchedNarrator[]
  known: DiscoveryReader | undefined
}

/** The tab in one format worked out from the library and the watches, and
 *  kept as the reader's projection for the next openings. */
const projectDiscovery = async (
  userId: UserId,
  language: Language,
  format: ReleaseFormat,
  now: Date,
): Promise<Discovery> => {
  // `now` is taken before the first read: a change made while the tab is
  // worked out leaves the projection stale.
  const [library, awaited] = await Promise.all([libraryOf(userId), awaitedOf(userId, now)])
  await rememberReader(userId, library, language, now)
  const { watches, authorWatches } = await watchesOf(library, format)
  const discovery = await discoveryOf(library, watches, authorWatches, awaited, format, now)
  await keepProjection({ userId, format, language, day: todayOf(now), builtAt: now, discovery })
  return discovery
}

/** Best effort: a projection not kept is worked out again at the next opening. */
const keepProjection = async (projection: DiscoveryProjection) => {
  try {
    const kept = await DiscoveryCommand.saveProjection(projection)
    if (!kept)
      logger.warn('discovery projection too large to keep', {
        userId: projection.userId,
        format: projection.format,
      })
  } catch (error) {
    logger.warn('discovery projection not kept', { error, userId: projection.userId })
  }
}

/** The reader's sagas and authors, and what the passes know of them. The
 *  library is read once, shared by the sagas and the authors. */
const libraryOf = async (userId: UserId, known?: DiscoveryReader): Promise<Library> => {
  const [followed, shelved, reader, books, opinions, heartedNarrators] = await Promise.all([
    SeriesUseCase.followed(userId),
    AuthorUseCase.shelvedAuthors(userId),
    known ? Promise.resolve(known) : DiscoveryQuery.reader(userId),
    BookQuery.all(userId),
    SeriesOpinionQuery.all(userId),
    NarratorQuery.favoriteKeys(userId),
  ])
  return {
    followed,
    shelved,
    sagas: watchedSagasOf(followed),
    authors: watchedAuthorsOf(
      shelved.filter(isFollowedAuthor),
      new Set(followed.filter(({ state }) => state === 'unfollowed').map(({ id }) => id)),
    ),
    narrators: watchedNarratorsOf(shelvedNarratorsOf(books, opinions), heartedNarrators),
    known: reader,
  }
}

/** The watches the tab needs in one format: its sagas' and its authors', the
 *  other format's left unread — each in one getAll. */
const watchesOf = async (library: Library, format: ReleaseFormat) => {
  const [watches, authorWatches] = await Promise.all([
    DiscoveryQuery.watches(
      library.sagas.filter((saga) => formatOf(saga.seriesId) === format).map(watchKeyOf),
    ),
    DiscoveryQuery.authorWatches(
      library.authors.filter((author) => author.format === format).map(authorWatchKeyOf),
    ),
  ])
  return { watches, authorWatches }
}

/** The editions the reader awaits, as the app draws them: the Authors shelf
 *  and an author's page add the ones announced or out to the works the web
 *  found. */
const awaitedOf = async (userId: UserId, now: Date): Promise<AwaitedEditionView[]> => {
  const awaited = await AwaitedEditionQuery.byUser(userId)
  const releases = await ReleaseQuery.byKeys(awaited.map((edition) => edition.watchKey))
  const today = todayOf(now)
  return awaited.map((edition) => viewOf(edition, releases.get(edition.watchKey), today))
}

/** The folded titles of editions awaited: a work the author's watch found
 *  under the same title is the same book, drawn once. */
const titlesOf = (awaited: readonly AwaitedEditionView[]): Set<string> =>
  new Set(awaited.map((view) => slugify(view.found?.title ?? view.source.title)))

/** The tab in one format out of the reader's library and the watches. */
const discoveryOf = async (
  library: Library,
  watches: ReadonlyMap<string, SagaWatch>,
  authorWatches: ReadonlyMap<string, AuthorWatch>,
  awaited: readonly AwaitedEditionView[],
  format: ReleaseFormat,
  now: Date,
): Promise<Discovery> => {
  const today = todayOf(now)
  let unwatched = 0
  let followedCount = 0
  const rows = library.followed.flatMap((series): SagaDiscovery[] => {
    if (!isDiscoverable(series)) return []
    if (formatOf(series.saga) !== format) return []
    followedCount += 1
    const watch = watches.get(watchKeyOf({ seriesId: series.saga, language: series.language }))
    const releases = releasesOf(series.books, watch, series.catalogue, today)
    if (!releases.watched) unwatched += 1
    const recent = recentReleasesOf(series.books, watch, series.catalogue, today)
    if (!releases.next && recent.length === 0) return []
    const missing = missingVolumesOf(series.books, watch, series.catalogue, today)
    return [{ ...releases, series, missing, recent }]
  })
  const sagas = inDiscoveryOrder(rows)
  const sagaTitles = new Set(
    [...watches.values()]
      .filter((watch) => formatOf(watch.seriesId) === format)
      .flatMap((watch) => watch.volumes.map((volume) => slugify(volume.title))),
  )
  const authors = await authorRowsOf(
    library,
    authorWatches,
    awaited,
    sagas,
    sagaTitles,
    format,
    today,
  )
  return {
    sagas,
    authors: authors.rows,
    unwatched: unwatched + authors.unwatched,
    followed: followedCount + authors.followed,
  }
}

/** The Authors shelf in one format: every author the reader holds in it with
 *  a work announced or just out, outside any saga they hold — read or heard,
 *  followed or set aside — and every author they hold with an edition awaited
 *  in it announced or out, in the tab's order, with their portraits. */
const authorRowsOf = async (
  library: Library,
  watches: ReadonlyMap<string, AuthorWatch>,
  awaitedViews: readonly AwaitedEditionView[],
  sagaRows: readonly SagaDiscovery[],
  sagaTitles: ReadonlySet<string>,
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
  const awaitedBy = awaitedByAuthorOf(
    awaitedViews,
    format,
    library.shelved.flatMap((author) => author.books),
  )
  const sagasBy = sagasByAuthorOf(sagaRows)
  const watched = library.authors.filter((author) => author.format === format)
  let unwatched = 0
  const rows = watched.flatMap((watchedAuthor): AuthorDiscovery[] => {
    const watch = watches.get(authorWatchKeyOf(watchedAuthor))
    const author = shelved.get(watchedAuthor.authorKey)
    const awaited = awaitedBy.get(watchedAuthor.authorKey) ?? []
    const sagas = sagasBy.get(watchedAuthor.authorKey) ?? []
    if (!watch) unwatched += 1
    if (!author) return []
    const releases = authorReleasesOf(
      author.books,
      sagaNames,
      watch,
      today,
      new Set([...titlesOf(awaited), ...sagaTitles]),
    )
    const quiet = !releases.next && releases.recent.length === 0
    if (quiet && awaited.length === 0 && sagas.length === 0) return []
    return [{ ...releases, awaited, sagas, author, language: watchedAuthor.language }]
  })
  // An author held only in the other format is on the shelf for what the
  // reader awaits of them in this one.
  const watchedKeys = new Set(watched.map((author) => author.authorKey))
  for (const [key, awaited] of awaitedBy) {
    const author = shelved.get(key)
    if (author && !watchedKeys.has(key)) {
      rows.push({ recent: [], awaited, sagas: sagasBy.get(key) ?? [], author })
    }
  }
  // An author with nothing dated of their own — an edition awaited, a volume
  // of a saga — closes the shelf.
  const dated = inDiscoveryOrder(rows)
  const ordered = [...dated, ...rows.filter((row) => !dated.includes(row))]
  const portrayed = await AuthorUseCase.withPortraits(ordered.map((row) => row.author))
  return {
    rows: ordered.map((row, index) => ({ ...row, author: portrayed[index] ?? row.author })),
    unwatched,
    followed: watched.length,
  }
}

/** The watches the hourly pass decides on, read by what can be due rather than
 *  whole: the stale ones and the ones looked up in the last day, by two range
 *  queries each; the followed keys that may have no watch, by what the last
 *  pass left; and the sagas a reader may hold further on than a fresh watch.
 *  Any other followed key has a watch fresher than its interval that no reader
 *  outgrew, looked up more than a day ago: due for no look and outside today's
 *  count. The readers handed to the due rules follow only the keys read, so
 *  the looks made, their order and the day's count are the ones a pass reading
 *  every watch makes. */
const watchesForThePass = async (everyone: readonly DiscoveryReader[], now: Date) => {
  const followed = followedKeysOf(everyone)
  const dayAgo = new Date(now.getTime() - 86_400_000)
  const olderThan = (every: number) => new Date(now.getTime() - every)
  const [state, sagaRows, authorRows, narratorRows] = await Promise.all([
    DiscoveryQuery.passState(),
    DiscoveryQuery.watchesCheckedOutside(olderThan(WATCH_EVERY_MS), dayAgo),
    DiscoveryQuery.authorWatchesCheckedOutside(olderThan(AUTHOR_WATCH_EVERY_MS), dayAgo),
    DiscoveryQuery.narratorWatchesCheckedOutside(olderThan(NARRATOR_WATCH_EVERY_MS), dayAgo),
  ])
  const unwatched = possiblyUnwatchedOf(followed, state)
  const [sagas, authors, narrators] = await Promise.all([
    withTheRestRead(
      sagaRows,
      followed.sagas,
      [...unwatched.sagas, ...mayBeBehindOf(everyone, now)],
      DiscoveryQuery.watches,
    ),
    withTheRestRead(authorRows, followed.authors, unwatched.authors, DiscoveryQuery.authorWatches),
    withTheRestRead(
      narratorRows,
      followed.narrators,
      unwatched.narrators,
      DiscoveryQuery.narratorWatches,
    ),
  ])
  const stillUnwatched = (keys: string[], watches: ReadonlyMap<string, unknown>) =>
    keys.filter((key) => !watches.has(key))
  return {
    watches: sagas.watches,
    authorWatches: authors.watches,
    narratorWatches: narrators.watches,
    readers: followingOnly(everyone, {
      sagas: sagas.keys,
      authors: authors.keys,
      narrators: narrators.keys,
    }),
    /** What to leave for the next pass, once this one's looks are written. */
    stateAfter: (): DiscoveryPassState => ({
      followed,
      unwatched: {
        sagas: stillUnwatched(unwatched.sagas, sagas.watches),
        authors: stillUnwatched(unwatched.authors, authors.watches),
        narrators: stillUnwatched(unwatched.narrators, narrators.watches),
      },
      savedAt: now,
    }),
  }
}

/** The followed watches among the rows queried, with the keys still to read
 *  read by key; and every key now known, watch or none. */
const withTheRestRead = async <W extends { key: string }>(
  rows: readonly W[],
  followed: readonly string[],
  toRead: readonly string[],
  read: (keys: readonly string[]) => Promise<Map<string, W>>,
): Promise<{ watches: Map<string, W>; keys: Set<string> }> => {
  const following = new Set(followed)
  const watches = new Map(
    rows.filter((watch) => following.has(watch.key)).map((watch) => [watch.key, watch]),
  )
  const missing = [...new Set(toRead)].filter((key) => following.has(key) && !watches.has(key))
  for (const [key, watch] of await read(missing)) watches.set(key, watch)
  return { watches, keys: new Set([...watches.keys(), ...missing]) }
}

/** The readers whose account still exists, by id; the others are forgotten. A
 *  pass that read an account just before it was deleted writes its reader back
 *  after the deletion erased it, and the reader's sagas would then be looked
 *  up every two weeks for nobody. One that cannot be forgotten now is next hour. */
const withoutAccountsGone = async (
  stored: readonly DiscoveryReader[],
  userIds: readonly UserId[],
): Promise<[UserId, DiscoveryReader][]> => {
  const accounts = new Set(userIds)
  const gone = stored.filter((reader) => !accounts.has(reader.userId))
  await Promise.all(
    gone.map(async ({ userId }) => {
      try {
        await DiscoveryCommand.deleteForUser(userId)
      } catch (error) {
        logger.warn('reader of a deleted account not forgotten', { error, userId })
      }
    }),
  )
  return stored
    .filter((reader) => accounts.has(reader.userId))
    .map((reader) => [reader.userId, reader])
}

/** Keep what the passes need to know of a reader, writing only when it moved:
 *  opening the tab every few minutes must not cost a write each time. */
const rememberReader = async (
  userId: UserId,
  { sagas, authors, narrators, known }: Pick<Library, 'sagas' | 'authors' | 'narrators' | 'known'>,
  language: Language,
  now: Date,
  force = false,
): Promise<DiscoveryReader> => {
  const unchanged =
    known !== undefined &&
    known.language === language &&
    JSON.stringify(known.sagas) === JSON.stringify(sagas) &&
    JSON.stringify(known.authors ?? []) === JSON.stringify(authors) &&
    JSON.stringify(known.narrators ?? []) === JSON.stringify(narrators) &&
    !readerIsStale(known, now)
  if (unchanged && !force) return known
  return DiscoveryCommand.rememberLibrary(
    { userId, language, sagas, authors, narrators, syncedAt: now },
    known,
  )
}
