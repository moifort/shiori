import type { SharedShelf } from '~/domain/analytics/types'
import type { AudibleRelease } from '~/domain/audible/types'
import { shelfKeyOf } from '~/domain/book/business-rules'
import type { Book, BookLanguage, Genre } from '~/domain/book/types'
import type { AlertKind } from '~/domain/notification/types'
import { followedSagasOf } from '~/domain/series/business-rules'
import type { SeriesName } from '~/domain/series/types'
import type { Language } from '~/domain/shared/language'
import type { AuthorName, BookTitle, UserId } from '~/domain/shared/types'
import { slugify } from '~/utils/slug'
import { ReleaseDate } from './primitives'
import type {
  DiscoverFeed,
  FriendFavorite,
  Release,
  ReleaseDate as ReleaseDateValue,
  ReleaseSubject,
  ReleaseWatch,
  Suggestion,
} from './types'

/** How often the weekly refresh runs for one reader, and how often they may
 *  ask for it themselves. */
export const REFRESH_EVERY_MS = 7 * 86_400_000
export const ON_DEMAND_EVERY_MS = 86_400_000
/** A genre's award list changes a few times a year: once a month is plenty. */
export const GENRE_LIST_EVERY_MS = 30 * 86_400_000
/** How long a release stays on the tab once out, and how late an alert may
 *  still go out for one the job missed. */
const RECENT_RELEASE_DAYS = 60
const ALERT_GRACE_DAYS = 14

/** What the reader's library says about what they like. */
export type Taste = {
  /** Hearted or five-star books, most recently touched first. */
  loved: Book[]
  /** Their leading genres, among the books they read or are reading. */
  genres: Genre[]
  /** The sagas they are working through, most recently active first. */
  sagas: { name: SeriesName; author?: AuthorName; language?: BookLanguage }[]
  /** The authors of the books they loved, most loved first. */
  authors: AuthorName[]
  /** Books they read in a language other than the app's. */
  foreignReads: Book[]
}

const LOVED_KEPT = 12
const GENRES_KEPT = 2
const SAGAS_KEPT = 8
const AUTHORS_KEPT = 5
const FOREIGN_KEPT = 6

const touchedAt = (book: Book): number =>
  (book.finishedAt ?? book.startedAt ?? book.updatedAt ?? book.addedAt).getTime()

const byRecent = (left: Book, right: Book) => touchedAt(right) - touchedAt(left)

const topBy = <T>(values: readonly T[], keep: number): T[] => {
  const counts = new Map<T, number>()
  for (const value of values) counts.set(value, (counts.get(value) ?? 0) + 1)
  return [...counts.entries()]
    .sort((left, right) => right[1] - left[1])
    .slice(0, keep)
    .map(([value]) => value)
}

export const tasteOf = (books: readonly Book[], language: Language): Taste => {
  const loved = books.filter((book) => book.favorite === true || book.rating === 5).sort(byRecent)
  const engaged = books.filter((book) => book.status === 'read' || book.status === 'reading')
  const sagas = followedSagasOf(books.filter((book) => book.status !== 'dropped'))
    .map((saga) => ({ saga, lastActivity: Math.max(...saga.books.map(touchedAt)) }))
    .sort((left, right) => right.lastActivity - left.lastActivity)
    .slice(0, SAGAS_KEPT)
    .map(({ saga }) => ({ name: saga.name, author: saga.author, language: saga.language }))
  return {
    loved: loved.slice(0, LOVED_KEPT),
    genres: topBy(
      engaged.flatMap((book) => (book.genre && book.genre !== 'other' ? [book.genre] : [])),
      GENRES_KEPT,
    ),
    sagas,
    authors: topBy(
      loved.flatMap((book) => (book.authors[0] ? [book.authors[0]] : [])),
      AUTHORS_KEPT,
    ),
    foreignReads: engaged
      .filter((book) => book.language !== undefined && book.language !== language)
      .sort(byRecent)
      .slice(0, FOREIGN_KEPT),
  }
}

// MARK: - Releases

export const subjectKeyOf = (subject: ReleaseSubject, language: Language): string => {
  switch (subject.kind) {
    case 'series':
      return `series--${slugify(subject.name)}--${slugify(subject.author ?? '')}--${subject.language ?? ''}`
    case 'author':
      return `author--${slugify(subject.author)}`
    case 'translation':
      return `translation--${shelfKeyOf(subject.title, subject.author)}--${language}`
  }
}

/** Everything the release tracker should watch for this reader. */
export const releaseSubjectsOf = (taste: Taste): ReleaseSubject[] => [
  ...taste.sagas.map(
    (saga): ReleaseSubject => ({
      kind: 'series',
      name: saga.name,
      author: saga.author,
      language: saga.language,
    }),
  ),
  ...taste.authors.map((author): ReleaseSubject => ({ kind: 'author', author })),
  ...taste.foreignReads
    // A saga's translation is the saga's next volumes, in the reader's own
    // language: watch the first book of it once, not every volume.
    .filter(
      (book, index, all) =>
        !book.series || all.findIndex((other) => other.series?.id === book.series?.id) === index,
    )
    .map(
      (book): ReleaseSubject => ({
        kind: 'translation',
        title: book.series ? (book.series.name as unknown as BookTitle) : book.title,
        author: book.authors[0],
      }),
    ),
]

/** Whether a watch is due for another look. */
export const watchIsStale = (watch: ReleaseWatch | undefined, now: Date): boolean =>
  !watch || now.getTime() - watch.checkedAt.getTime() > REFRESH_EVERY_MS

const KIND_OF_SUBJECT = {
  series: 'series-volume',
  author: 'author-release',
  translation: 'translation',
} as const satisfies Record<ReleaseSubject['kind'], AlertKind>

/** The last day a date can mean: a book announced for "2027" may come out on
 *  December 31st, and is not over before then. */
const lastDayOf = (date: ReleaseDateValue): string =>
  date.length === 10 ? date : date.length === 7 ? `${date}-31` : `${date}-12-31`

const dayMinus = (today: string, days: number): string => {
  const [year, month, day] = today.split('-').map(Number)
  return new Date(Date.UTC(year, month - 1, day) - days * 86_400_000).toISOString().slice(0, 10)
}

/** The releases one reader cares about, drawn from the watches of their
 *  subjects: upcoming or out in the last two months, never a book they own,
 *  the soonest first. */
export const releasesOf = (
  watches: readonly { subject: ReleaseSubject; watch: ReleaseWatch }[],
  ownedKeys: ReadonlySet<string>,
  today: string,
  reasonOf: (subject: ReleaseSubject) => string,
): Release[] => {
  const since = dayMinus(today, RECENT_RELEASE_DAYS)
  const seen = new Set<string>()
  const releases: Release[] = []
  for (const { subject, watch } of watches) {
    for (const release of watch.releases) {
      const key = shelfKeyOf(release.title, release.authors[0])
      if (ownedKeys.has(key) || lastDayOf(release.date) < since) continue
      const kind: AlertKind =
        subject.kind === 'series' && release.format === 'audiobook'
          ? 'audible-release'
          : KIND_OF_SUBJECT[subject.kind]
      const releaseKey = `${kind}--${key}--${release.format}--${release.language ?? ''}`
      if (seen.has(releaseKey)) continue
      seen.add(releaseKey)
      releases.push({
        key: releaseKey,
        kind,
        title: release.title,
        authors: release.authors,
        language: release.language,
        format: release.format,
        isbn13: release.isbn13,
        series:
          subject.kind === 'series' ? { name: subject.name, volume: release.volume } : undefined,
        date: release.date,
        releaseDate: release.date,
        reason: reasonOf(subject),
      })
    }
  }
  return releases.sort((left, right) => left.date.localeCompare(right.date))
}

/** The Audible releases of the reader's sagas, as suggestions, and the ones
 *  still ahead of their date as releases too. */
export const audibleShelvesOf = (
  found: readonly AudibleRelease[],
  language: Language,
): { suggestions: Suggestion[]; releases: Release[] } => {
  const suggestions = found.map((book): Suggestion => {
    const date = book.releaseDate
      ? ReleaseDate(book.releaseDate.toISOString().slice(0, 10))
      : undefined
    return {
      key: shelfKeyOf(book.title, book.authors[0]),
      title: book.title,
      authors: book.authors,
      language: book.language,
      format: 'audiobook',
      genre: book.genre,
      series: book.series ? { name: book.series.name, volume: book.series.volume } : undefined,
      synopsis: book.synopsis,
      coverUrl: book.coverUrl,
      isbn13: book.isbn13,
      audibleAsin: book.asin,
      releaseDate: date,
      reason: audibleReasonOf(book, language),
    }
  })
  return {
    suggestions,
    releases: suggestions.flatMap((suggestion): Release[] =>
      suggestion.releaseDate
        ? [
            {
              ...suggestion,
              key: `audible-release--${suggestion.key}--audiobook--${suggestion.language ?? ''}`,
              kind: 'audible-release',
              date: suggestion.releaseDate,
            },
          ]
        : [],
    ),
  }
}

const audibleReasonOf = (book: AudibleRelease, language: Language): string => {
  const volume = book.series?.volume
  const saga = book.series?.name ?? ''
  if (language === 'fr')
    return volume !== undefined
      ? `Tome ${volume} de ${saga}, la suite de ce que vous écoutez`
      : `La suite de ${saga} sur Audible`
  return volume !== undefined
    ? `Book ${volume} of ${saga}, next after what you listened to`
    : `More of ${saga} on Audible`
}

/** The releases whose alert is due today: out on a known day, today or in the
 *  last two weeks, and not pushed yet. */
export const dueReleases = (
  releases: readonly Release[],
  notified: readonly string[],
  today: string,
): Release[] => {
  const since = dayMinus(today, ALERT_GRACE_DAYS)
  const already = new Set(notified)
  return releases.filter(
    (release) =>
      release.date.length === 10 &&
      release.date <= today &&
      release.date >= since &&
      !already.has(release.key),
  )
}

/** The alert for one release, in the reader's language. */
export const alertOf = (release: Release, language: Language): { title: string; body: string } => {
  const author = release.authors[0] ?? ''
  const saga = release.series?.name
  const volume = release.series?.volume
  const fr = language === 'fr'
  switch (release.kind) {
    case 'series-volume':
      return {
        title: fr ? 'Nouveau tome' : 'New volume',
        body: saga
          ? fr
            ? `${release.title}${volume !== undefined ? `, tome ${volume} de ${saga}` : ''}, sort aujourd'hui.`
            : `${release.title}${volume !== undefined ? `, book ${volume} of ${saga}` : ''}, is out today.`
          : fr
            ? `${release.title} sort aujourd'hui.`
            : `${release.title} is out today.`,
      }
    case 'translation':
      return {
        title: fr ? 'Enfin traduit' : 'Now translated',
        body: fr
          ? `${release.title} de ${author} paraît en français.`
          : `${release.title} by ${author} is out in your language.`,
      }
    case 'audible-release':
      return {
        title: fr ? 'Nouveau sur Audible' : 'New on Audible',
        body: fr
          ? `${release.title}${saga ? ` (${saga})` : ''} est disponible en livre audio.`
          : `${release.title}${saga ? ` (${saga})` : ''} is out as an audiobook.`,
      }
    case 'author-release':
      return {
        title: fr ? `Nouveau ${author}` : `New from ${author}`,
        body: fr ? `${release.title} sort aujourd'hui.` : `${release.title} is out today.`,
      }
  }
}

// MARK: - What the reader sees

/** Leave out what the reader owns or dismissed, and anything proposed twice. */
export const unseen = <T extends { key: string }>(
  items: readonly T[],
  ownedKeys: ReadonlySet<string>,
  dismissed: readonly string[],
): T[] => {
  const skipped = new Set([...ownedKeys, ...dismissed])
  const kept: T[] = []
  for (const item of items) {
    if (skipped.has(item.key)) continue
    skipped.add(item.key)
    kept.push(item)
  }
  return kept
}

/** How many of the friends' hearts the tab shows. */
const FRIENDS_FAVORITES_SHOWN = 20

/** A friend's heart before its cover is signed. */
export type UnsignedFriendFavorite = Omit<FriendFavorite, 'coverUrl'> & {
  cover: Pick<SharedShelf['favorites'][number], 'coverPath' | 'publishedCoverUrl'>
}

/** The books the reader's friends hearted and the reader does not own, the
 *  most hearted first, each with every friend who hearted it. */
export const friendsFavoritesOf = (
  shelves: ReadonlyMap<UserId, SharedShelf>,
  names: ReadonlyMap<UserId, string>,
  ownedKeys: ReadonlySet<string>,
  dismissed: readonly string[],
): UnsignedFriendFavorite[] => {
  const skipped = new Set([...ownedKeys, ...dismissed])
  const byKey = new Map<string, UnsignedFriendFavorite>()
  for (const [friendId, shelf] of shelves) {
    const name = names.get(friendId)
    for (const favorite of shelf.favorites) {
      const key = shelfKeyOf(favorite.title, favorite.authors[0])
      if (skipped.has(key)) continue
      const known = byKey.get(key)
      if (known) {
        if (name) known.friendNames.push(name)
        continue
      }
      byKey.set(key, {
        key,
        friendId,
        bookId: favorite.id,
        friendNames: name ? [name] : [],
        title: favorite.title,
        authors: favorite.authors,
        format: favorite.format,
        series: favorite.series
          ? { name: favorite.series.name, volume: favorite.series.volume }
          : undefined,
        cover: { coverPath: favorite.coverPath, publishedCoverUrl: favorite.publishedCoverUrl },
      })
    }
  }
  return [...byKey.values()]
    .sort((left, right) => right.friendNames.length - left.friendNames.length)
    .slice(0, FRIENDS_FAVORITES_SHOWN)
}

/** Whether the reader may ask for a fresh set now. */
export const canRefresh = (feed: DiscoverFeed | undefined, now: Date): boolean =>
  !feed?.refreshedAt || now.getTime() - feed.refreshedAt.getTime() > ON_DEMAND_EVERY_MS

export const emptyFeed = (userId: UserId, language: Language): DiscoverFeed => ({
  userId,
  language,
  audible: [],
  releases: [],
  becauseYouLoved: [],
  offTrail: [],
  genres: [],
  dismissed: [],
  notified: [],
})

export const genreListKeyOf = (genre: Genre, language: Language): string => `${genre}--${language}`
