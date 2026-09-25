import type { AudibleMarketplace } from '~/domain/audible/types'
import { shelfKeyOf } from '~/domain/book/business-rules'
import type { Book, BookLanguage } from '~/domain/book/types'
import type { FoundVolume } from '~/domain/series/business-rules'
import { isAudioSeries } from '~/domain/series/primitives'
import type { SeriesId } from '~/domain/series/types'
import type { FollowedSeries } from '~/domain/series/use-case'
import type { Language } from '~/domain/shared/language'
import type { BookTitle, UserId } from '~/domain/shared/types'
import type { ObjectPath } from '~/system/object-store/types'
import { slugify } from '~/utils/slug'
import type {
  BookPreview,
  DatedEdition,
  DiscoverFeed,
  Release,
  ReleaseDate as ReleaseDateValue,
  ReleaseEdition,
  ReleaseFormat,
  ReleaseWatch,
  WatchedWork,
} from './types'

/** How often the scheduled refresh runs for one reader — Audible is asked
 *  every day, since a preorder can open any morning — and how often they may
 *  ask for it themselves. */
export const REFRESH_EVERY_MS = 86_400_000
/** How often the web is searched again for one work: a publisher announces a
 *  translation months ahead, and the call is the expensive part. */
export const WATCH_EVERY_MS = 7 * 86_400_000
/** How late an alert may still go out for an edition the job missed. */
const ALERT_GRACE_DAYS = 14

const touchedAt = (book: Book): number =>
  (book.finishedAt ?? book.startedAt ?? book.updatedAt ?? book.addedAt).getTime()

// MARK: - What the reader follows

/** A saga worth watching for its next volume: one being read, one finished as
 *  far as the world knows — which is exactly when an announced volume matters —
 *  and one of unknown state, every volume read and no catalogue to say whether
 *  more exist. Not one set aside, nor one not started. */
const isWatched = (saga: FollowedSeries) =>
  saga.state !== 'unfollowed' && saga.state !== 'not-started'

const seriesWork = (
  saga: FollowedSeries,
  language: BookLanguage,
  readIn: BookLanguage,
): WatchedWork => {
  const first = saga.books.find((book) => book.coverPath || book.publishedCoverUrl) ?? saga.books[0]
  return {
    key: `series--${saga.id}--${language}`,
    kind: 'series',
    seriesId: saga.id,
    title: saga.name as unknown as BookTitle,
    author: saga.author,
    language,
    readIn,
    volumesRead: saga.books
      .filter((book) => book.status === 'read' || book.status === 'reading')
      .flatMap((book) => (book.series?.volume !== undefined ? [book.series.volume] : []))
      .sort((left, right) => left - right),
    cover: { coverPath: first?.coverPath, publishedCoverUrl: first?.publishedCoverUrl },
    lastActivity: saga.shelvedAt.getTime(),
  }
}

/** Every work the reader follows, in every language the web is searched in:
 *  each saga being read or finished, in the language they hold it in — for
 *  its next volume — and in the app's when that differs and they hold no copy
 *  in it — for its translation; each book on its own read in another language,
 *  in the app's. The most recently touched first. */
export const watchedWorksOf = (
  followed: readonly FollowedSeries[],
  books: readonly Book[],
  language: Language,
): WatchedWork[] => {
  const works = new Map<string, WatchedWork>()
  const held = new Set(followed.map((saga) => `${saga.id}|${saga.language ?? ''}`))
  for (const saga of followed) {
    if (!saga.language || !isWatched(saga)) continue
    const own = seriesWork(saga, saga.language, saga.language)
    works.set(own.key, own)
    if (saga.language !== language && !held.has(`${saga.id}|${language}`)) {
      const translated = seriesWork(saga, language, saga.language)
      works.set(translated.key, translated)
    }
  }
  for (const book of books) {
    if (book.series || (book.status !== 'read' && book.status !== 'reading')) continue
    if (book.language === undefined || book.language === language) continue
    const key = `book--${shelfKeyOf(book.title, book.authors[0])}--${language}`
    const known = works.get(key)
    if (known) {
      known.lastActivity = Math.max(known.lastActivity, touchedAt(book))
      continue
    }
    works.set(key, {
      key,
      kind: 'book',
      title: book.title,
      author: book.authors[0],
      language,
      readIn: book.language,
      volumesRead: [],
      cover: { coverPath: book.coverPath, publishedCoverUrl: book.publishedCoverUrl },
      lastActivity: touchedAt(book),
    })
  }
  return [...works.values()].sort((left, right) => right.lastActivity - left.lastActivity)
}

/** What the reader already holds, edition by edition: a book by its title in
 *  its language, a volume of a saga by its number in its language. An edition
 *  they own is not one to propose — and only in that language: a French
 *  edition titled like the English one ("Red Rising") must not pass for the
 *  copy the reader read. */
export const ownedEditionsOf = (books: readonly Book[]): Set<string> =>
  new Set(
    books.flatMap((book) => {
      if (!book.language) return []
      const keys = [`${book.language}|${shelfKeyOf(book.title, book.authors[0])}`]
      if (book.series?.volume !== undefined && book.series.kind === 'main')
        keys.push(`${book.language}|${book.series.id}#${book.series.volume}`)
      return keys
    }),
  )

// MARK: - The shared web watch

/** Whether a work is due for another look on the web. */
export const watchIsStale = (watch: ReleaseWatch | undefined, now: Date): boolean =>
  !watch || now.getTime() - watch.checkedAt.getTime() > WATCH_EVERY_MS

/** The editions a saga is made of: its recordings for the saga heard, its
 *  printed books for the saga read. */
const releaseFormatOf = (seriesId: SeriesId): ReleaseFormat =>
  isAudioSeries(seriesId) ? 'audiobook' : 'book'

/** What a saga's watch writes into its catalogue: the volumes found in the
 *  saga's own format, numbered, with their date, title and cover in that
 *  language. A recording often comes years after its book, so the saga heard is
 *  dated by its recordings and the saga read by its books. */
export const foundVolumesOf = (watch: ReleaseWatch, seriesId: SeriesId): FoundVolume[] =>
  watch.editions.flatMap((edition) =>
    edition.format === releaseFormatOf(seriesId) && edition.volume !== undefined
      ? [
          {
            volume: edition.volume,
            title: edition.title,
            date: edition.date,
            coverUrl: edition.coverUrl,
          },
        ]
      : [],
  )

// MARK: - What the reader sees

/** The last day a date can mean: a book announced for "2027" may come out on
 *  December 31st, and is not out before then. */
const lastDayOf = (date: ReleaseDateValue): string =>
  date.length === 10 ? date : date.length === 7 ? `${date}-31` : `${date}-12-31`

const dayMinus = (today: string, days: number): string => {
  const [year, month, day] = today.split('-').map(Number)
  return new Date(Date.UTC(year, month - 1, day) - days * 86_400_000).toISOString().slice(0, 10)
}

/** Whether an edition is still to come: a day after today, or a month or a
 *  year not over yet. */
export const isUpcoming = (edition: ReleaseEdition, today: string): boolean =>
  edition.date !== undefined &&
  (edition.date.length === 10 ? edition.date > today : lastDayOf(edition.date) >= today)

const byVolumeThenDate = (left: ReleaseEdition, right: ReleaseEdition) =>
  (left.volume ?? 0) - (right.volume ?? 0) ||
  (left.date ?? '').localeCompare(right.date ?? '') ||
  left.format.localeCompare(right.format)

/** A work's editions as this reader sees them: no recording for a reader with
 *  no Audible connection, only the saga's own format for a saga — the saga
 *  heard and the saga read each have a row, and each announces its own — one
 *  edition per volume and format, never one the reader already owns in that
 *  language. */
export const editionsOf = (
  work: WatchedWork,
  watch: ReleaseWatch | undefined,
  recordings: boolean,
  owned: ReadonlySet<string>,
): ReleaseEdition[] => {
  // A book on its own has one edition per format; a saga, one per volume.
  const slotOf = (edition: ReleaseEdition) =>
    work.kind === 'book'
      ? edition.format
      : `${edition.format}--${edition.volume ?? slugify(edition.title)}`
  const merged = new Map<string, ReleaseEdition>()
  for (const edition of watch?.editions ?? []) {
    if (edition.format === 'audiobook' && !recordings) continue
    if (work.seriesId && edition.format !== releaseFormatOf(work.seriesId)) continue
    if (!merged.has(slotOf(edition))) merged.set(slotOf(edition), edition)
  }
  const ownedHere = (edition: ReleaseEdition) =>
    owned.has(`${work.language}|${shelfKeyOf(edition.title, work.author)}`) ||
    (work.seriesId !== undefined &&
      edition.volume !== undefined &&
      owned.has(`${work.language}|${work.seriesId}#${edition.volume}`))
  return [...merged.values()].filter((edition) => !ownedHere(edition)).sort(byVolumeThenDate)
}

/** The soonest edition still to come, by the last day its date can mean. */
const nextDateOf = (
  editions: readonly ReleaseEdition[],
  today: string,
): ReleaseDateValue | undefined =>
  editions
    .filter((edition) => isUpcoming(edition, today))
    .flatMap((edition) => (edition.date ? [edition.date] : []))
    .sort((left, right) => lastDayOf(left).localeCompare(lastDayOf(right)))[0]

/** A release before its cover is signed: the reader's own photo of their
 *  copy, when no edition brought a cover of its own. */
export type UnsignedRelease = Release & { coverPath?: ObjectPath }

/** The tab: every work the reader follows with something to say in that
 *  language, except the ones they said they are not interested in. A work with
 *  an edition still to come is upcoming, the soonest first. A translation out
 *  already of what they read in another language may interest them, the most
 *  recently read first. The next volumes of a saga already out in the language
 *  the reader reads it in are the series screen's business, not this tab's. */
export const releasesOf = (
  works: readonly WatchedWork[],
  watches: ReadonlyMap<string, ReleaseWatch>,
  feed: Pick<DiscoverFeed, 'dismissed'>,
  marketplace: AudibleMarketplace | undefined,
  owned: ReadonlySet<string>,
  today: string,
): { upcoming: UnsignedRelease[]; maybe: UnsignedRelease[] } => {
  const dismissed = new Set(feed.dismissed)
  const releases = works.flatMap((work): UnsignedRelease[] => {
    if (dismissed.has(work.key)) return []
    const watch = watches.get(work.key)
    const editions = editionsOf(work, watch, marketplace !== undefined, owned)
    if (editions.length === 0) return []
    const localTitle = watch?.localTitle ?? (work.kind === 'book' ? editions[0].title : undefined)
    const coverUrl =
      editions.find((edition) => edition.coverUrl)?.coverUrl ?? work.cover.publishedCoverUrl
    return [
      {
        key: work.key,
        kind: work.kind,
        seriesId: work.seriesId,
        language: work.language,
        readIn: work.readIn,
        title: localTitle ?? work.title,
        author: work.author,
        coverUrl,
        coverPath: coverUrl ? undefined : work.cover.coverPath,
        editions,
        nextDate: nextDateOf(editions, today),
        audibleMarketplace: marketplace,
      },
    ]
  })
  return {
    upcoming: releases
      .filter((release) => release.nextDate !== undefined)
      .sort((left, right) =>
        lastDayOf(left.nextDate as ReleaseDateValue).localeCompare(
          lastDayOf(right.nextDate as ReleaseDateValue),
        ),
      ),
    maybe: releases.filter(
      (release) => release.nextDate === undefined && release.language !== release.readIn,
    ),
  }
}

// MARK: - Book previews

export const previewKeyOf = (title: string, author: string | undefined, language: Language) =>
  `${shelfKeyOf(title, author)}--${language}`

/** Whether a preview must be built: never built, or built before its book came
 *  out and out since — an announcement lists less than a book on sale. */
export const previewIsStale = (preview: BookPreview | undefined, today: string): boolean => {
  if (!preview) return true
  if (!preview.releaseDate) return false
  const out = lastDayOf(preview.releaseDate)
  return out < today && preview.builtAt.toISOString().slice(0, 10) <= out
}

// MARK: - Alerts

const editionKeyOf = (workKey: string, edition: ReleaseEdition): string =>
  `${workKey}--${edition.format}--${edition.volume ?? slugify(edition.title)}`

/** The editions an alert could still go out for: an exact day, no more than
 *  the grace period ago. Kept on the feed so the daily pass reads nothing
 *  else. */
export const datedEditionsOf = (releases: readonly Release[], today: string): DatedEdition[] => {
  const since = dayMinus(today, ALERT_GRACE_DAYS)
  return releases.flatMap((release) =>
    release.editions.flatMap((edition): DatedEdition[] =>
      edition.date && edition.date.length === 10 && edition.date >= since
        ? [
            {
              key: editionKeyOf(release.key, edition),
              workKey: release.key,
              title: edition.title,
              volume: edition.volume,
              format: edition.format,
              date: edition.date,
              language: release.language,
              translation: release.language !== release.readIn,
            },
          ]
        : [],
    ),
  )
}

/** The editions whose alert is due today: out on a known day, today or in the
 *  last two weeks, not pushed yet, of a work the reader still wants. */
export const dueEditions = (
  feed: Pick<DiscoverFeed, 'dated' | 'notified' | 'dismissed'>,
  today: string,
): DatedEdition[] => {
  const since = dayMinus(today, ALERT_GRACE_DAYS)
  const skipped = new Set([...feed.notified, ...feed.dismissed])
  return feed.dated.filter(
    (edition) =>
      edition.date <= today &&
      edition.date >= since &&
      !skipped.has(edition.key) &&
      !skipped.has(edition.workKey),
  )
}

/** The alert for one edition, in the app's language: a translation of what
 *  the reader read, or the next volume of a saga in the language they read it
 *  in. Worded for the day it goes out, which may be a little after the edition
 *  did. */
export const alertOf = (
  edition: DatedEdition,
  language: Language,
): { title: string; body: string } => {
  const audio = edition.format === 'audiobook'
  const { translation } = edition
  if (language === 'fr') {
    const named = `« ${edition.title} »${edition.volume !== undefined ? `, tome ${edition.volume},` : ''}`
    return translation
      ? {
          title: 'Enfin traduit',
          body: `${named} est disponible en français${audio ? ' en livre audio' : ''}.`,
        }
      : {
          title: 'Nouveau tome',
          body: `${named} est sorti${audio ? ' en livre audio' : ''}.`,
        }
  }
  const named = `"${edition.title}"${edition.volume !== undefined ? `, book ${edition.volume},` : ''}`
  return translation
    ? {
        title: 'Now translated',
        body: `${named} is out in English${audio ? ' as an audiobook' : ''}.`,
      }
    : { title: 'New volume', body: `${named} is out${audio ? ' as an audiobook' : ''}.` }
}

// MARK: - The feed

/** Whether the reader may ask for a fresh look now, and whether the scheduled
 *  pass is due for them: the same day-old rule for both. */
export const canRefresh = (feed: DiscoverFeed | undefined, now: Date): boolean =>
  !feed?.refreshedAt || now.getTime() - feed.refreshedAt.getTime() > REFRESH_EVERY_MS

export const emptyFeed = (userId: UserId, language: Language): DiscoverFeed => ({
  userId,
  language,
  dated: [],
  dismissed: [],
  notified: [],
})
