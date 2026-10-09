import { awaitableFormatsOf, stateOf } from '~/domain/awaited-edition/business-rules'
import { AwaitedEditionQuery } from '~/domain/awaited-edition/query'
import type { AwaitedEditionId } from '~/domain/awaited-edition/types'
import { AwaitedEditionUseCase, type WatchSeed } from '~/domain/awaited-edition/use-case'
import { AwardCommand } from '~/domain/award/command'
import { AwardQuery } from '~/domain/award/query'
import { BookQuery } from '~/domain/book/query'
import type { BookLanguage, Genre } from '~/domain/book/types'
import { releaseDescriptionKeyOf, todayOf } from '~/domain/discovery/business-rules'
import { DiscoveryQuery } from '~/domain/discovery/query'
import type { ReleaseFormat } from '~/domain/discovery/types'
import type { Language } from '~/domain/shared/language'
import type { UserId } from '~/domain/shared/types'
import { createLogger } from '~/system/logger'
import {
  AWARDS_BY_GENRE,
  genresOf,
  hasRead,
  INTEREST_LASTS_MS,
  INTEREST_RENEWED_AFTER_MS,
  isDue,
  isHeld,
  RECENT_COUNT,
  watchKeyOf,
  worksOf,
} from './business-rules'
import type { AwardedWork, AwardedWorkView, AwardShelf } from './types'

const logger = createLogger('award')

/** How many grounded calls run side by side, as the release watches run theirs. */
const CALLS_AT_ONCE = 5

/** Where the hourly pass stops looking winners up, counted from the start of
 *  the run: after the awaited editions and the sagas, which come first, and
 *  well inside the function's three minutes. */
const SCHEDULED_BUDGET_MS = 140_000

const FORMATS: readonly ReleaseFormat[] = ['book', 'audiobook']

export namespace AwardUseCase {
  /** The award winners of the reader's genre — or of the one asked for, when
   *  the reader reads it enough — in one format and the app's language. Null
   *  when the reader reads no genre with awards enough. Renews the genre's
   *  interest, so the hourly pass keeps its winners looked up. */
  export const shelf = async (
    userId: UserId,
    format: ReleaseFormat,
    appLanguage: Language,
    asked: Genre | undefined,
    now = new Date(),
  ): Promise<AwardShelf | null> => {
    const books = await BookQuery.all(userId)
    const genres = genresOf(books)
    const genre = asked && genres.includes(asked) ? asked : genres[0]
    if (!genre) return null
    const awards = AWARDS_BY_GENRE[genre] ?? []
    await renewInterest(genre, appLanguage, now)

    const works = worksOf(awards)
    const keys = works.map((work) => watchKeyOf(work, format, appLanguage))
    const [watches, awaited] = await Promise.all([
      AwaitedEditionQuery.watches(keys),
      AwaitedEditionQuery.byUser(userId),
    ])
    const awaitedByKey = new Map(
      awaited
        .filter((edition) => edition.format === format && edition.language === appLanguage)
        .map((edition) => [edition.watchKey, edition.id]),
    )
    const today = todayOf(now)
    const views = new Map(
      works.map((work, index) => {
        const watchKey = keys[index]
        return [
          work.key,
          viewOf(
            work,
            format,
            appLanguage,
            watchKey,
            watches.get(watchKey),
            awaitedByKey.get(watchKey),
            today,
          ),
        ] as const
      }),
    )
    const shown = (view: AwardedWorkView) => !isHeld(view.work, format, view.watch?.found, books)
    const recent = await withDescribedCovers(
      [...views.values()].filter(shown).slice(0, RECENT_COUNT),
      appLanguage,
    )

    return {
      genre,
      genres,
      recent,
      awards: awards.map((award) => {
        const winners = works.filter((work) => work.mentions.some((m) => m.award === award))
        return {
          award,
          winners: winners
            .map((work) => views.get(work.key))
            .filter((view): view is AwardedWorkView => view !== undefined && shown(view))
            .sort(
              (left, right) =>
                yearOf(right.work, award) - yearOf(left.work, award) ||
                left.work.title.localeCompare(right.work.title),
            ),
          readCount: winners.filter((work) =>
            hasRead(work, views.get(work.key)?.watch?.found, books),
          ).length,
          total: winners.length,
        }
      }),
    }
  }

  /** The hourly pass's share: the winners of every genre somebody looked at in
   *  the last three months, in both formats and the language they looked in —
   *  the ones never looked up first — until the budget is spent. */
  export const watchDue = async (
    now = new Date(),
    budgetMs = SCHEDULED_BUDGET_MS,
    startedAt = Date.now(),
  ): Promise<{ watched: number; failed: number; deferred: number }> => {
    const overBudget = () => Date.now() - startedAt > budgetMs
    const interests = (await AwardQuery.interests()).filter(
      (interest) => now.getTime() - interest.requestedAt.getTime() < INTEREST_LASTS_MS,
    )
    const seeds = new Map<string, WatchSeed>()
    for (const { genre, language } of interests)
      for (const work of worksOf(AWARDS_BY_GENRE[genre] ?? []))
        for (const format of FORMATS) {
          const key = watchKeyOf(work, format, language)
          if (!seeds.has(key)) seeds.set(key, seedOf(work, format, language, key))
        }
    if (seeds.size === 0) return { watched: 0, failed: 0, deferred: 0 }
    const watches = await AwaitedEditionQuery.watches([...seeds.keys()])
    const today = todayOf(now)
    const due = [...seeds.values()]
      .filter((seed) => isDue(watches.get(seed.key), now, today))
      // Never looked up first, then the oldest look.
      .sort(
        (left, right) =>
          (watches.get(left.key)?.checkedAt.getTime() ?? 0) -
          (watches.get(right.key)?.checkedAt.getTime() ?? 0),
      )
    let watched = 0
    let failed = 0
    for (let start = 0; start < due.length; start += CALLS_AT_ONCE) {
      if (overBudget()) return { watched, failed, deferred: due.length - start }
      await Promise.all(
        due.slice(start, start + CALLS_AT_ONCE).map(async (seed) => {
          try {
            await AwaitedEditionUseCase.lookUpEdition(seed, watches.get(seed.key), now)
            watched += 1
          } catch (error) {
            failed += 1
            logger.warn('award winner lookup failed', { error, watchKey: seed.key })
          }
        }),
      )
    }
    return { watched, failed, deferred: 0 }
  }
}

const yearOf = (work: AwardedWork, award: string) =>
  work.mentions.find((mention) => mention.award === award)?.year ?? 0

const viewOf = (
  work: AwardedWork,
  format: ReleaseFormat,
  language: Language,
  watchKey: string,
  watch: AwardedWorkView['watch'],
  awaitedId: AwaitedEditionId | undefined,
  today: string,
): AwardedWorkView => {
  const state = stateOf(watch?.found, format, today)
  const formats = awaitableFormatsOf({ language: work.language, format: 'book' }, language)
  return {
    work,
    format,
    language,
    watchKey,
    ...(watch ? { watch } : {}),
    state,
    awaitable: state !== 'available' && !awaitedId && formats.includes(format),
    ...(awaitedId ? { awaitedId } : {}),
  }
}

/** The strip's winners with no cover found, given the one their page found
 *  when a reader opened it: the description is kept under the key that page
 *  asks it by, so one getAll reads them all. */
const withDescribedCovers = async (
  views: AwardedWorkView[],
  appLanguage: Language,
): Promise<AwardedWorkView[]> => {
  const bare = views.filter((view) => !view.watch?.found?.coverUrl)
  if (bare.length === 0) return views
  const keyOf = (view: AwardedWorkView) =>
    releaseDescriptionKeyOf(
      {
        title: view.watch?.found?.title ?? view.work.title,
        authors: view.work.authors,
        format: view.format,
        ...(view.state === 'unannounced' ? { language: view.work.language } : {}),
      },
      appLanguage,
    )
  const kept = await DiscoveryQuery.descriptions(bare.map(keyOf))
  return views.map((view) => {
    if (view.watch?.found?.coverUrl) return view
    const coverUrl = kept.get(keyOf(view))?.description.book.coverUrl
    return coverUrl ? { ...view, describedCoverUrl: coverUrl } : view
  })
}

const seedOf = (
  work: AwardedWork,
  format: ReleaseFormat,
  language: BookLanguage,
  key: string,
): WatchSeed => ({
  key,
  title: work.title,
  ...(work.authors[0] ? { author: work.authors[0] } : {}),
  originalLanguage: work.language,
  format,
  language,
})

/** Marks the genre as looked at in that language, at most once a day. */
const renewInterest = async (genre: Genre, language: BookLanguage, now: Date) => {
  const key = `${genre}--${language}`
  try {
    const known = await AwardQuery.interest(key)
    if (known && now.getTime() - known.requestedAt.getTime() < INTEREST_RENEWED_AFTER_MS) return
    await AwardCommand.saveInterest({ key, genre, language, requestedAt: now })
  } catch (error) {
    logger.warn('award interest not renewed', { error, key })
  }
}
