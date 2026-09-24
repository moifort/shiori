import type { AudibleRelease } from '~/domain/audible/types'
import { shelfKeyOf } from '~/domain/book/business-rules'
import type { Book } from '~/domain/book/types'
import type { Language } from '~/domain/shared/language'
import type { BookTitle, UserId } from '~/domain/shared/types'
import type { ObjectPath } from '~/system/object-store/types'
import { slugify } from '~/utils/slug'
import { ReleaseDate } from './primitives'
import type {
  DatedEdition,
  DiscoverFeed,
  ForeignWork,
  ReleaseDate as ReleaseDateValue,
  TranslatedEdition,
  Translation,
  TranslationWatch,
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

// MARK: - What the reader read in another language

/** Every work the reader read, or is reading, in a language other than the
 *  app's: one per saga, one per book outside a saga, the most recently touched
 *  first. */
export const foreignWorksOf = (books: readonly Book[], language: Language): ForeignWork[] => {
  const works = new Map<string, ForeignWork>()
  const read = books
    .filter((book) => book.status === 'read' || book.status === 'reading')
    .sort((left, right) => (left.series?.volume ?? 0) - (right.series?.volume ?? 0))
  for (const book of read) {
    if (book.language === undefined || book.language === language) continue
    const key = book.series
      ? `series--${book.series.id}`
      : `book--${shelfKeyOf(book.title, book.authors[0])}`
    const volume = book.series?.volume
    const known = works.get(key)
    if (known) {
      if (volume !== undefined && !known.volumesRead.includes(volume))
        known.volumesRead.push(volume)
      known.lastActivity = Math.max(known.lastActivity, touchedAt(book))
      if (!known.cover.coverPath && !known.cover.publishedCoverUrl)
        known.cover = { coverPath: book.coverPath, publishedCoverUrl: book.publishedCoverUrl }
      continue
    }
    works.set(key, {
      key,
      kind: book.series ? 'series' : 'book',
      title: book.series ? (book.series.name as unknown as BookTitle) : book.title,
      author: book.authors[0],
      language: book.language,
      volumesRead: volume === undefined ? [] : [volume],
      cover: { coverPath: book.coverPath, publishedCoverUrl: book.publishedCoverUrl },
      lastActivity: touchedAt(book),
    })
  }
  return [...works.values()].sort((left, right) => right.lastActivity - left.lastActivity)
}

/** The books the reader already has in the app's language: a translation they
 *  own is not one to propose. Only those — a French edition titled like the
 *  English one ("Red Rising") must not pass for the copy the reader read. */
export const ownedInLanguage = (books: readonly Book[], language: Language): Set<string> =>
  new Set(
    books
      .filter((book) => book.language === language)
      .map((book) => shelfKeyOf(book.title, book.authors[0])),
  )

// MARK: - The shared web watch

export const watchKeyOf = (work: ForeignWork, language: Language): string =>
  `${work.key}--${language}`

/** Whether a work is due for another look on the web. */
export const watchIsStale = (watch: TranslationWatch | undefined, now: Date): boolean =>
  !watch || now.getTime() - watch.checkedAt.getTime() > WATCH_EVERY_MS

// MARK: - Audible

/** The recordings of one work among what the reader's Audible marketplace
 *  lists for its author: the saga's volumes, matched on the saga's name, or
 *  the book itself, matched on its title — as the reader knows it, or as the
 *  web says it was translated. One recording per volume, the first listed. */
export const audibleTranslationsOf = (
  work: ForeignWork,
  translatedTitle: BookTitle | undefined,
  recordings: readonly AudibleRelease[],
): TranslatedEdition[] => {
  const names = new Set([
    slugify(work.title),
    ...(translatedTitle ? [slugify(translatedTitle)] : []),
  ])
  const author = work.author ? slugify(work.author) : undefined
  const seen = new Set<string>()
  return recordings.flatMap((recording): TranslatedEdition[] => {
    if (author && !recording.authors.some((name) => slugify(name) === author)) return []
    const matches =
      work.kind === 'series'
        ? recording.series !== undefined && names.has(slugify(recording.series.name))
        : names.has(slugify(recording.title))
    if (!matches) return []
    const slot = String(recording.series?.volume ?? slugify(recording.title))
    if (seen.has(slot)) return []
    seen.add(slot)
    return [
      {
        title: recording.title,
        volume: work.kind === 'series' ? recording.series?.volume : undefined,
        format: 'audiobook',
        date: recording.releaseDate
          ? ReleaseDate(recording.releaseDate.toISOString().slice(0, 10))
          : undefined,
        isbn13: recording.isbn13,
        audibleAsin: recording.asin,
        coverUrl: recording.coverUrl,
      },
    ]
  })
}

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
export const isUpcoming = (edition: TranslatedEdition, today: string): boolean =>
  edition.date !== undefined &&
  (edition.date.length === 10 ? edition.date > today : lastDayOf(edition.date) >= today)

const byVolumeThenDate = (left: TranslatedEdition, right: TranslatedEdition) =>
  (left.volume ?? 0) - (right.volume ?? 0) ||
  (left.date ?? '').localeCompare(right.date ?? '') ||
  left.format.localeCompare(right.format)

/** A work's editions as this reader sees them. The web's, with Audible's own
 *  listing in place of the web's recordings for a reader connected to it — its
 *  dates are the ones the store keeps — and no recording at all for a reader
 *  who is not. Never an edition the reader already owns. */
export const editionsOf = (
  work: ForeignWork,
  watch: TranslationWatch | undefined,
  audible: readonly TranslatedEdition[] | undefined,
  owned: ReadonlySet<string>,
): TranslatedEdition[] => {
  // A book on its own has one edition per format; a saga, one per volume.
  const slotOf = (edition: TranslatedEdition) =>
    work.kind === 'book'
      ? edition.format
      : `${edition.format}--${edition.volume ?? slugify(edition.title)}`
  const merged = new Map<string, TranslatedEdition>()
  for (const edition of watch?.editions ?? []) {
    if (edition.format === 'audiobook' && audible === undefined) continue
    if (!merged.has(slotOf(edition))) merged.set(slotOf(edition), edition)
  }
  for (const edition of audible ?? []) merged.set(slotOf(edition), edition)
  return [...merged.values()]
    .filter((edition) => !owned.has(shelfKeyOf(edition.title, work.author)))
    .sort(byVolumeThenDate)
}

/** The soonest edition still to come, by the last day its date can mean. */
const nextDateOf = (
  editions: readonly TranslatedEdition[],
  today: string,
): ReleaseDateValue | undefined =>
  editions
    .filter((edition) => isUpcoming(edition, today))
    .flatMap((edition) => (edition.date ? [edition.date] : []))
    .sort((left, right) => lastDayOf(left).localeCompare(lastDayOf(right)))[0]

/** A translation before its cover is signed: the reader's own photo of their
 *  copy is only drawn when no translated edition has a cover. */
export type UnsignedTranslation = Translation & { coverPath?: ObjectPath }

/** The tab: every work the reader read in another language that exists or is
 *  announced in theirs, except the ones they said they are not interested in.
 *  A work with an edition still to come is upcoming, the soonest first; the
 *  rest are available, the most recently read first. */
export const translationsOf = (
  works: readonly ForeignWork[],
  watches: ReadonlyMap<string, TranslationWatch>,
  feed: Pick<DiscoverFeed, 'language' | 'audible' | 'dismissed'>,
  owned: ReadonlySet<string>,
  today: string,
): { upcoming: UnsignedTranslation[]; available: UnsignedTranslation[] } => {
  const dismissed = new Set(feed.dismissed)
  const audibleByWork = feed.audible
    ? new Map(feed.audible.works.map((entry) => [entry.workKey, entry.editions]))
    : undefined
  const translations = works.flatMap((work): UnsignedTranslation[] => {
    if (dismissed.has(work.key)) return []
    const watch = watches.get(watchKeyOf(work, feed.language))
    const audible = audibleByWork ? (audibleByWork.get(work.key) ?? []) : undefined
    const editions = editionsOf(work, watch, audible, owned)
    if (editions.length === 0) return []
    const translatedTitle =
      watch?.translatedTitle ?? (work.kind === 'book' ? editions[0].title : undefined)
    const coverUrl =
      editions.find((edition) => edition.coverUrl)?.coverUrl ?? work.cover.publishedCoverUrl
    return [
      {
        key: work.key,
        kind: work.kind,
        title: translatedTitle ?? work.title,
        originalTitle: work.title,
        author: work.author,
        originalLanguage: work.language,
        volumesRead: [...work.volumesRead].sort((left, right) => left - right),
        coverUrl,
        coverPath: coverUrl ? undefined : work.cover.coverPath,
        editions,
        nextDate: nextDateOf(editions, today),
        audibleMarketplace: feed.audible?.marketplace,
      },
    ]
  })
  return {
    upcoming: translations
      .filter((translation) => translation.nextDate !== undefined)
      .sort((left, right) =>
        lastDayOf(left.nextDate as ReleaseDateValue).localeCompare(
          lastDayOf(right.nextDate as ReleaseDateValue),
        ),
      ),
    available: translations.filter((translation) => translation.nextDate === undefined),
  }
}

// MARK: - Alerts

const editionKeyOf = (workKey: string, edition: TranslatedEdition): string =>
  `${workKey}--${edition.format}--${edition.volume ?? slugify(edition.title)}`

/** The editions an alert could still go out for: an exact day, no more than
 *  the grace period ago. Kept on the feed so the daily pass reads nothing
 *  else. */
export const datedEditionsOf = (
  translations: readonly Translation[],
  today: string,
): DatedEdition[] => {
  const since = dayMinus(today, ALERT_GRACE_DAYS)
  return translations.flatMap((translation) =>
    translation.editions.flatMap((edition): DatedEdition[] =>
      edition.date && edition.date.length === 10 && edition.date >= since
        ? [
            {
              key: editionKeyOf(translation.key, edition),
              workKey: translation.key,
              title: edition.title,
              volume: edition.volume,
              format: edition.format,
              date: edition.date,
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

/** The alert for one edition, in the reader's language. Worded for the day it
 *  goes out, which may be a little after the edition did. */
export const alertOf = (
  edition: DatedEdition,
  language: Language,
): { title: string; body: string } => {
  const audio = edition.format === 'audiobook'
  if (language === 'fr')
    return {
      title: 'Enfin traduit',
      body: `« ${edition.title} »${edition.volume !== undefined ? `, tome ${edition.volume},` : ''} est disponible en français${audio ? ' en livre audio' : ''}.`,
    }
  return {
    title: 'Now translated',
    body: `"${edition.title}"${edition.volume !== undefined ? `, book ${edition.volume},` : ''} is out in English${audio ? ' as an audiobook' : ''}.`,
  }
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
