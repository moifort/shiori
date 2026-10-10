import { awaitableFormatsOf, stateOf } from '~/domain/awaited-edition/business-rules'
import { AwaitedEditionQuery } from '~/domain/awaited-edition/query'
import type { AwaitedEditionId } from '~/domain/awaited-edition/types'
import { AwardCommand } from '~/domain/award/command'
import { AwardQuery } from '~/domain/award/query'
import { BookQuery } from '~/domain/book/query'
import type { Genre } from '~/domain/book/types'
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
  isHeld,
  latestWinnersOf,
  latestYearsOf,
  MAX_AWARD_SECTIONS,
  RECENT_COUNT,
  sectionGenreOf,
  watchKeyOf,
  worksOf,
} from './business-rules'
import { winnersAfter } from './infrastructure/wikidata'
import {
  AWARDS,
  type Award,
  type AwardedWork,
  type AwardedWorkView,
  type AwardSection,
  type AwardShelf,
} from './types'

const logger = createLogger('award')

export namespace AwardUseCase {
  /** The latest award winners of the reader's genre — or of the one asked
   *  for, when the reader reads it enough — in one format and the app's
   *  language. Null when the reader reads no genre with awards enough. */
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
    const works = await latestWorksOf(awards)
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

  /** One section per genre the reader reads most, three at most, the most
   *  read first: the winners of its awards' latest ceremony they do not hold,
   *  in one format and the app's language. A work two genres' awards crowned is
   *  drawn in one section only — see `sectionGenreOf`. Where an edition stands
   *  is read off the shared watches, never looked up here: a winner is looked
   *  up once a reader awaits it, by the awaited editions' own pass. */
  export const sections = async (
    userId: UserId,
    format: ReleaseFormat,
    appLanguage: Language,
    now = new Date(),
  ): Promise<AwardSection[]> => {
    const books = await BookQuery.all(userId)
    const genres = genresOf(books).slice(0, MAX_AWARD_SECTIONS)
    if (genres.length === 0) return []
    const works = await latestWorksOf([
      ...new Set(genres.flatMap((genre) => AWARDS_BY_GENRE[genre] ?? [])),
    ])
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
    const shown = works.flatMap((work, index) => {
      const watchKey = keys[index]
      const view = viewOf(
        work,
        format,
        appLanguage,
        watchKey,
        watches.get(watchKey),
        awaitedByKey.get(watchKey),
        today,
      )
      return isHeld(work, format, view.watch?.found, books) ? [] : [view]
    })
    const picked = genres.map((genre) => ({
      genre,
      winners: shown
        .filter((view) => sectionGenreOf(view.work, genres) === genre)
        .slice(0, RECENT_COUNT),
    }))
    const described = new Map(
      (
        await withDescribedCovers(
          picked.flatMap((section) => section.winners),
          appLanguage,
        )
      ).map((view) => [view.work.key, view]),
    )
    return picked
      .map(({ genre, winners }) => ({
        genre,
        winners: winners.map((view) => described.get(view.work.key) ?? view),
      }))
      .filter((section) => section.winners.length > 0)
  }

  /** The daily pass: asks Wikidata, for every award, the winners of the
   *  ceremonies after the latest one known, and keeps each new year. It runs
   *  every day, so a ceremony is taken within a day of Wikidata recording it.
   *  No model call. An award Wikidata fails on is logged and asked again the
   *  next day. */
  export const watchWinners = async (
    now = new Date(),
  ): Promise<{ found: number; failed: number }> => {
    const latest = latestYearsOf(await AwardQuery.foundWinners())
    let found = 0
    let failed = 0
    for (const award of AWARDS) {
      try {
        const winners = (await winnersAfter(award, latest[award])).filter(
          ({ year }) => year <= now.getUTCFullYear(),
        )
        const byYear = Map.groupBy(winners, ({ year }) => year)
        for (const [year, crowned] of byYear) {
          await AwardCommand.saveWinners({
            key: `${award}~${year}`,
            award,
            year,
            winners: crowned.map(({ title, authors }) => ({ title, authors })),
            foundAt: now,
          })
          found += 1
          logger.info('award winners found', { award, year, count: crowned.length })
        }
      } catch (error) {
        failed += 1
        logger.warn('award winners not read', { error, award })
      }
    }
    return { found, failed }
  }
}

/** The works of these awards' latest ceremonies, the years found by the daily
 *  pass included. */
const latestWorksOf = async (awards: readonly Award[]): Promise<AwardedWork[]> => {
  const found = await AwardQuery.foundWinners()
  return worksOf(awards, (award) => latestWinnersOf(award, found))
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
