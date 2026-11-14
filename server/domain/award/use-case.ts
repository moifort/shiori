import { awaitableFormatsOf, stateOf } from '~/domain/awaited-edition/business-rules'
import { AwaitedEditionQuery } from '~/domain/awaited-edition/query'
import type { AwaitedEditionId } from '~/domain/awaited-edition/types'
import { AwardCommand } from '~/domain/award/command'
import { AwardQuery } from '~/domain/award/query'
import { BookQuery } from '~/domain/book/query'
import type { Genre } from '~/domain/book/types'
import { todayOf } from '~/domain/discovery/business-rules'
import { RELEASE_FORMATS, type ReleaseFormat } from '~/domain/discovery/types'
import { watchOf } from '~/domain/release/business-rules'
import { ReleaseQuery } from '~/domain/release/query'
import type { Release, ReleaseView } from '~/domain/release/types'
import { type DescribeRefusal, ReleaseUseCase } from '~/domain/release/use-case'
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
  releaseIdentityOf,
  releaseShownOf,
  sectionGenreOf,
  watchKeyOf,
  winnerStateOf,
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
    const [books, dismissed] = await Promise.all([
      BookQuery.all(userId),
      AwardQuery.dismissedKeys(userId),
    ])
    const genres = genresOf(books)
    const genre = asked && genres.includes(asked) ? asked : genres[0]
    if (!genre) return null
    const awards = AWARDS_BY_GENRE[genre] ?? []
    const works = await latestWorksOf(awards)
    const editions = await editionsOf(works, userId, appLanguage)
    const today = todayOf(now)
    const views = new Map(
      works.map((work) => [work.key, viewOf(work, format, appLanguage, editions, today)] as const),
    )
    const shown = (view: AwardedWorkView) =>
      !dismissed.has(view.work.key) && !isHeld(view.work, format, view.watch?.found, books)
    const recent = [...views.values()].filter(shown).slice(0, RECENT_COUNT)

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
    const [books, dismissed] = await Promise.all([
      BookQuery.all(userId),
      AwardQuery.dismissedKeys(userId),
    ])
    const genres = genresOf(books).slice(0, MAX_AWARD_SECTIONS)
    if (genres.length === 0) return []
    const works = await latestWorksOf([
      ...new Set(genres.flatMap((genre) => AWARDS_BY_GENRE[genre] ?? [])),
    ])
    const editions = await editionsOf(works, userId, appLanguage)
    const today = todayOf(now)
    const shown = works.flatMap((work) => {
      const view = viewOf(work, format, appLanguage, editions, today)
      return dismissed.has(work.key) || isHeld(work, format, view.watch?.found, books) ? [] : [view]
    })
    const picked = genres.map((genre) => ({
      genre,
      winners: shown
        .filter((view) => sectionGenreOf(view.work, genres) === genre)
        .slice(0, RECENT_COUNT),
    }))
    return picked.filter((section) => section.winners.length > 0)
  }

  /** Describe one winner's edition for its page, as its release, in one
   *  format and the app's language: `not-found` for a novel no ceremony
   *  crowned lately. */
  export const describe = async (
    userId: UserId,
    key: string,
    format: ReleaseFormat,
    appLanguage: Language,
    now = new Date(),
  ): Promise<ReleaseView | DescribeRefusal | 'not-found'> => {
    const work = (await latestWorksOf(AWARDS)).find((candidate) => candidate.key === key)
    if (!work) return 'not-found'
    const editions = await editionsOf([work], userId, appLanguage)
    const view = viewOf(work, format, appLanguage, editions, todayOf(now))
    return ReleaseUseCase.describeShown(
      userId,
      releaseIdentityOf(view),
      releaseShownOf(view),
      appLanguage,
      now,
    )
  }

  /** "Pas intéressé" on a winner: gone from the lists, in every format. */
  export const dismiss = (userId: UserId, key: string) => AwardCommand.dismiss(userId, key)

  /** The red thumb pressed again: the winner is listed again. */
  export const reconsider = (userId: UserId, key: string) => AwardCommand.reconsider(userId, key)

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

/** The shared watches of these works in both formats, and the editions the
 *  reader awaits, by watch key: one getAll and one query, whatever the format
 *  shown, so a page offers to await the recording of a translation listed. */
const editionsOf = async (
  works: readonly AwardedWork[],
  userId: UserId,
  appLanguage: Language,
): Promise<Editions> => {
  const keys = works.flatMap((work) =>
    RELEASE_FORMATS.map((format) => watchKeyOf(work, format, appLanguage)),
  )
  const [releases, awaited] = await Promise.all([
    ReleaseQuery.byKeys(keys),
    AwaitedEditionQuery.byUser(userId),
  ])
  return {
    releases,
    awaitedByKey: new Map(awaited.map((edition) => [edition.watchKey, edition.id])),
  }
}

type Editions = {
  releases: Map<string, Release>
  awaitedByKey: Map<string, AwaitedEditionId>
}

const viewOf = (
  work: AwardedWork,
  format: ReleaseFormat,
  language: Language,
  editions: Editions,
  today: string,
): AwardedWorkView => {
  const watchKey = watchKeyOf(work, format, language)
  const release = editions.releases.get(watchKey)
  const watch = watchOf(release)
  const awaitedId = editions.awaitedByKey.get(watchKey)
  const awaitableFormats = awaitableFormatsOf(
    { language: work.language, format: 'book' },
    language,
  ).filter((candidate) => {
    const key = watchKeyOf(work, candidate, language)
    const found = watchOf(editions.releases.get(key))?.found
    return stateOf(found, candidate, today) !== 'available' && !editions.awaitedByKey.has(key)
  })
  return {
    work,
    format,
    language,
    watchKey,
    ...(watch ? { watch } : {}),
    state: winnerStateOf(work, format, language, watch?.found, today),
    awaitable: awaitableFormats.includes(format),
    awaitableFormats,
    ...(awaitedId ? { awaitedId } : {}),
  }
}
