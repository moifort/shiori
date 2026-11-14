// The web looks behind Découvrir: a saga, an author or a narrator searched
// for with a grounded model call, its finds checked against Audible and Amazon,
// and the watch kept for every reader who follows it. Split from use-case.ts,
// which decides what to look up and when.

import { AdminCommand } from '~/domain/admin/command'
import type { BookLanguage } from '~/domain/book/types'
import {
  AUTHOR_RECENT_DAYS,
  authorWatchKeyOf,
  catalogueVolumesOf,
  formatOf,
  lastVolumeOutOf,
  mergedNarratedWorks,
  mergedVolumes,
  mergedWorks,
  narratorWatchKeyOf,
  onAudible,
  todayOf,
  watchKeyOf,
} from '~/domain/discovery/business-rules'
import { DiscoveryCommand } from '~/domain/discovery/command'
import { amazonEditionOf } from '~/domain/discovery/infrastructure/amazon-catalogue'
import {
  audibleProductOf,
  audibleSeriesOf,
} from '~/domain/discovery/infrastructure/audible-catalogue'
import { narratedWorksFrom, volumesFrom, worksFrom } from '~/domain/discovery/parsing'
import {
  authorReleasesPrompt,
  narratorReleasesPrompt,
  releasesPrompt,
} from '~/domain/discovery/prompts'
import {
  AUTHOR_RELEASES_SCHEMA,
  type AuthorReleasesOutput,
  NARRATOR_RELEASES_SCHEMA,
  type NarratorReleasesOutput,
  RELEASES_SCHEMA,
  type ReleasesOutput,
} from '~/domain/discovery/schemas'
import type {
  AuthorWatch,
  FoundVolume,
  FoundWork,
  NarratedWork,
  NarratorWatch,
  SagaWatch,
  WatchedAuthor,
  WatchedNarrator,
  WatchedSaga,
} from '~/domain/discovery/types'
import { publishedCoverOf } from '~/domain/scan/published-cover'
import { SeriesCommand } from '~/domain/series/command'
import { generate } from '~/system/gemini'
import { isSpendCapReached } from '~/system/gemini/spend-cap'
import { createLogger } from '~/system/logger'
import { slugify } from '~/utils/slug'

const logger = createLogger('discovery')

/** How many grounded calls run side by side: a library of sagas is caught up
 *  over a few hours rather than in one request the function would not live
 *  through. */
export const CALLS_AT_ONCE = 5

/** Look these sagas up on the web, a few side by side, until the budget is
 *  spent, keeping each watch in `watches` and writing what was found into the
 *  sagas' catalogues. A lookup that fails leaves its saga as it was. A refusal
 *  for want of Gemini credit ends the pass: every saga after it would be
 *  refused too, each its own Sentry event, every hour until someone tops the
 *  credit up. What it did not reach is deferred, and `refused` says why. */
export const lookUpAll = async (
  sagas: readonly WatchedSaga[],
  watches: Map<string, SagaWatch>,
  now: Date,
  overBudget: () => boolean,
): Promise<{ watched: number; failed: number; deferred: number; refused: boolean }> => {
  let watched = 0
  let failed = 0
  let refusal: unknown
  for (let start = 0; start < sagas.length; start += CALLS_AT_ONCE) {
    if (refusal) {
      logger.warn('release watch stopped, AI credit spent', { error: refusal })
      return { watched, failed, deferred: sagas.length - start, refused: true }
    }
    if (overBudget()) return { watched, failed, deferred: sagas.length - start, refused: false }
    const found = await Promise.all(
      sagas.slice(start, start + CALLS_AT_ONCE).map(async (saga) => {
        try {
          return await lookUp(saga, watches.get(watchKeyOf(saga)), now)
        } catch (error) {
          failed += 1
          if (isSpendCapReached(error)) refusal = error
          else logger.warn('saga release lookup failed', { error, saga: watchKeyOf(saga) })
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
  if (refusal) logger.warn('release watch stopped, AI credit spent', { error: refusal })
  return { watched, failed, deferred: 0, refused: refusal !== undefined }
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
export const withCover = async <Found extends Pick<FoundVolume, 'coverUrl' | 'isbn13'>>(
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
 *  from another store, or as a Kindle ASIN. An ASIN Audible does not know,
 *  nor finds a recording for by its title, is dropped and the volume offered
 *  through a search; one Audible could not be asked about keeps the one confirmed last
 *  time, if any. */
export const confirmedOnAudible = async <
  Found extends Pick<FoundVolume, 'asin' | 'title' | 'date' | 'coverUrl'>,
>(
  volume: Found,
  known: Found | undefined,
  language: BookLanguage,
): Promise<Found> => {
  const { asin } = volume
  if (!asin) return volume
  if (asin === known?.asin) return volume
  const product = await audibleProductOf(asin, language, volume.title)
  if (product === 'unreachable') return { ...volume, asin: known?.asin }
  // The web search names a Kindle ASIN, or one no store sells, every run:
  // dropping it is what this check is for, not a failure anyone has to fix.
  if (product === 'unknown') {
    logger.info('Audible ASIN not confirmed', { asin, title: volume.title })
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
export const lookUp = async (
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
    return keepWatch(saga, now, onAudible(direct, previous?.volumes ?? [], today), previous)
  const after = previous ? lastVolumeOutOf(previous.volumes, today) : undefined
  const { value, usage } = await generate<ReleasesOutput>({
    step: 'discovery-releases',
    parts: [{ text: releasesPrompt({ ...saga }, today, after) }],
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
    return keepWatch(
      saga,
      now,
      onAudible(listed, [...(previous?.volumes ?? []), ...found], today),
      previous,
    )
  return keepWatch(saga, now, mergedVolumes(previous?.volumes ?? [], found), previous)
}

/** One saga's watch as Audible's own listing of its series gives it, marked as
 *  asked; the watch it had, marked as asked, when Audible files the recording
 *  under no series; nothing when Audible could not be asked, or files it under
 *  none and the saga was never looked up — the hourly pass will. */
export const listedOnAudible = async (
  saga: WatchedSaga,
  previous: SagaWatch | undefined,
  now: Date,
): Promise<SagaWatch | undefined> => {
  if (!saga.asin) return undefined
  const listing = await audibleSeriesOf(saga.asin, saga.language)
  if (listing === 'unreachable') return undefined
  if (Array.isArray(listing))
    return keepWatch(
      saga,
      now,
      onAudible(listing, previous?.volumes ?? [], todayOf(now)),
      previous,
      true,
    )
  if (!previous) return undefined
  const watch: SagaWatch = { ...previous, audibleListed: true }
  await DiscoveryCommand.saveWatch(watch)
  return watch
}

const keepWatch = async (
  saga: WatchedSaga,
  now: Date,
  volumes: FoundVolume[],
  previous: SagaWatch | undefined,
  listed = previous?.audibleListed === true,
): Promise<SagaWatch> => {
  const watch: SagaWatch = {
    key: watchKeyOf(saga),
    seriesId: saga.seriesId,
    name: saga.name,
    author: saga.author,
    language: saga.language,
    checkedAt: now,
    volumes,
    ...(listed ? { audibleListed: true as const } : {}),
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
export const confirmedOnAmazon = async <
  Found extends Pick<FoundVolume, 'isbn13' | 'title' | 'date'>,
>(
  volume: Found,
  language: BookLanguage,
): Promise<Found> => {
  const { isbn13 } = volume
  if (!isbn13) return volume
  const edition = await amazonEditionOf(isbn13, language)
  if (edition === 'unreachable') return volume
  // The web search names ISBNs that never existed every run: dropping them is
  // what this check is for, not a failure anyone has to fix.
  if (edition === 'unknown') {
    logger.info('Amazon ISBN not confirmed', { isbn13, title: volume.title })
    return { ...volume, isbn13: undefined }
  }
  return edition.releaseDate ? { ...volume, date: edition.releaseDate } : volume
}

/** A printed saga's volumes are bought in a bookshop: an ASIN the model gave
 *  anyway is not kept. */
export const withoutAsin = <Found extends { asin?: unknown }>(volume: Found): Found => ({
  ...volume,
  asin: undefined,
})

// MARK: - The authors

/** Look these authors up on the web, a few side by side, until the budget is
 *  spent, keeping each watch in `watches`. A lookup that fails leaves its
 *  author as they were; a refusal for want of Gemini credit ends the pass, as
 *  it ends the sagas'. */
export const lookUpAllAuthors = async (
  authors: readonly WatchedAuthor[],
  watches: Map<string, AuthorWatch>,
  now: Date,
  overBudget: () => boolean,
): Promise<{ watched: number; failed: number; deferred: number }> => {
  let watched = 0
  let failed = 0
  let refusal: unknown
  for (let start = 0; start < authors.length; start += CALLS_AT_ONCE) {
    if (refusal || overBudget()) {
      if (refusal) logger.warn('release watch stopped, AI credit spent', { error: refusal })
      return { watched, failed, deferred: authors.length - start }
    }
    const found = await Promise.all(
      authors.slice(start, start + CALLS_AT_ONCE).map(async (author) => {
        try {
          return await lookUpAuthor(author, watches.get(authorWatchKeyOf(author)), now)
        } catch (error) {
          failed += 1
          if (isSpendCapReached(error)) refusal = error
          else
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
  if (refusal) logger.warn('release watch stopped, AI credit spent', { error: refusal })
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
  const since = new Date(now.getTime() - AUTHOR_RECENT_DAYS * 86_400_000).toISOString().slice(0, 10)
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

// MARK: - The narrators

/** Look these narrators up on the web, a few side by side, until the budget is
 *  spent, keeping each watch in `watches`. Mirrors the authors' pass: a lookup
 *  that fails leaves its narrator as they were, and a refusal for want of
 *  Gemini credit ends the pass. */
export const lookUpAllNarrators = async (
  narrators: readonly WatchedNarrator[],
  watches: Map<string, NarratorWatch>,
  now: Date,
  overBudget: () => boolean,
): Promise<{ watched: number; failed: number; deferred: number; refused: boolean }> => {
  let watched = 0
  let failed = 0
  let refusal: unknown
  for (let start = 0; start < narrators.length; start += CALLS_AT_ONCE) {
    if (refusal || overBudget()) {
      if (refusal) logger.warn('release watch stopped, AI credit spent', { error: refusal })
      return { watched, failed, deferred: narrators.length - start, refused: refusal !== undefined }
    }
    const found = await Promise.all(
      narrators.slice(start, start + CALLS_AT_ONCE).map(async (narrator) => {
        try {
          return await lookUpNarrator(narrator, watches.get(narratorWatchKeyOf(narrator)), now)
        } catch (error) {
          failed += 1
          if (isSpendCapReached(error)) refusal = error
          else
            logger.warn('narrator release lookup failed', {
              error,
              narrator: narratorWatchKeyOf(narrator),
            })
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
  if (refusal) logger.warn('release watch stopped, AI credit spent', { error: refusal })
  return { watched, failed, deferred: 0, refused: refusal !== undefined }
}

/** Look one narrator up in one language and keep what was found: a recording
 *  kept with its ASIN only once Audible's own catalogue confirms it, dated as
 *  Audible dates it. One grounded call, shared by every reader who follows
 *  them, every three months. */
const lookUpNarrator = async (
  narrator: WatchedNarrator,
  previous: NarratorWatch | undefined,
  now: Date,
): Promise<NarratorWatch> => {
  const today = todayOf(now)
  const since = new Date(now.getTime() - AUTHOR_RECENT_DAYS * 86_400_000).toISOString().slice(0, 10)
  const { value, usage } = await generate<NarratorReleasesOutput>({
    step: 'discovery-narrator-releases',
    parts: [{ text: narratorReleasesPrompt(narrator, today, since) }],
    responseSchema: NARRATOR_RELEASES_SCHEMA,
    grounded: true,
  })
  await recordUsage(usage)
  const known = new Map((previous?.works ?? []).map((work) => [slugify(work.title), work]))
  const found: NarratedWork[] = []
  for (const work of narratedWorksFrom(value.works ?? [])) {
    const confirmed = await confirmedOnAudible(
      work,
      known.get(slugify(work.title)),
      narrator.language,
    )
    found.push({ ...confirmed, authors: work.authors })
  }
  const watch: NarratorWatch = {
    key: narratorWatchKeyOf(narrator),
    narratorKey: narrator.narratorKey,
    name: narrator.name,
    language: narrator.language,
    checkedAt: now,
    works: mergedNarratedWorks(previous?.works ?? [], found, today),
  }
  await DiscoveryCommand.saveNarratorWatch(watch)
  return watch
}
