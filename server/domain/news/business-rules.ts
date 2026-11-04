import type { SharedActivity, SharedActivityKind } from '~/domain/analytics/types'
import type { AwaitedEditionView } from '~/domain/awaited-edition/types'
import { drawnFormatOf, shelfKeyOf } from '~/domain/book/business-rules'
import type { Book, BookFormat } from '~/domain/book/types'
import type {
  AuthorDiscovery,
  Discovery,
  FoundVolume,
  NarratorWatch,
  ReleaseFormat,
} from '~/domain/discovery/types'
import type { Friend } from '~/domain/friendship/types'
import type { FeedEvent, FeedEventKind, NarratorNews, UpcomingRelease } from '~/domain/news/types'
import type { FollowedSeries } from '~/domain/series/use-case'
import { slugify } from '~/utils/slug'

const KINDS: Partial<Record<SharedActivityKind, FeedEventKind>> = {
  reading: 'started',
  read: 'finished',
  hearted: 'loved',
}

const storyOf = (activity: SharedActivity): string =>
  shelfKeyOf(activity.book.title, activity.book.authors[0])

/** Every friend's recent moves worth telling, newest first, a book in progress
 *  on the day it was started, not the last day it was read. The books a friend
 *  keeps to themselves never reached their shared shelf, so none is here.
 *
 *  `held` holds the shelf keys of the stories the reader already has. */
export const feedEventsOf = (
  friends: readonly Friend[],
  held: ReadonlySet<string>,
): FeedEvent[] => {
  const startedBy = new Map<string, Set<string>>()
  for (const friend of friends)
    for (const activity of friend.shelf?.recentActivity ?? []) {
      if (activity.kind !== 'reading') continue
      const readers = startedBy.get(storyOf(activity)) ?? new Set<string>()
      readers.add(friend.userId)
      startedBy.set(storyOf(activity), readers)
    }
  return friends
    .flatMap((friend) =>
      (friend.shelf?.recentActivity ?? []).flatMap((activity): FeedEvent[] => {
        const kind = KINDS[activity.kind]
        if (!kind) return []
        const story = storyOf(activity)
        return [
          {
            id: `${friend.userId}~${kind}~${activity.book.id}`,
            kind,
            at: activity.startedAt ?? activity.at,
            friend: {
              userId: friend.userId,
              firstName: friend.firstName,
              ...(friend.avatar ? { avatar: friend.avatar } : {}),
            },
            book: activity.book,
            ...(activity.rating ? { rating: activity.rating } : {}),
            alsoStartedBy:
              kind === 'started'
                ? [...(startedBy.get(story) ?? [])].filter((id) => id !== friend.userId).length
                : 0,
            inLibrary: held.has(story),
          },
        ]
      }),
    )
    .filter(
      (event, _index, events) =>
        // A finish the friend also hearted is told once, as the heart.
        event.kind !== 'finished' ||
        !events.some((other) => other.kind === 'loved' && other.id === loved(event)),
    )
    .sort(newestFirst)
}

const loved = (event: FeedEvent): string => event.id.replace('~finished~', '~loved~')

const newestFirst = (left: FeedEvent, right: FeedEvent): number =>
  right.at.getTime() - left.at.getTime() || (left.id < right.id ? -1 : left.id > right.id ? 1 : 0)

/** The cursor of the event a page ended on: its instant, then its id. */
export const cursorOf = (event: FeedEvent): string => `${event.at.getTime()}|${event.id}`

/** One page of the feed after a cursor. A cursor that does not parse restarts
 *  from the top, as the other cursors of the API do. */
export const feedPageOf = (
  events: readonly FeedEvent[],
  limit: number,
  after?: string,
): { events: FeedEvent[]; nextCursor?: string } => {
  const separator = after?.indexOf('|') ?? -1
  const instant = after && separator > 0 ? Number(after.slice(0, separator)) : Number.NaN
  const id = after && separator > 0 ? after.slice(separator + 1) : ''
  const rest = Number.isNaN(instant)
    ? events
    : events.filter(
        (event) =>
          event.at.getTime() < instant || (event.at.getTime() === instant && event.id > id),
      )
  const page = rest.slice(0, limit)
  const last = page.at(-1)
  return {
    events: page,
    ...(rest.length > limit && last ? { nextCursor: cursorOf(last) } : {}),
  }
}

// MARK: - Upcoming releases

const sagaRelease = (
  series: FollowedSeries,
  volume: FoundVolume,
  format: ReleaseFormat,
): UpcomingRelease => ({
  id: `saga~${series.saga}~${volume.number}~${format}`,
  source: 'saga',
  format: format === 'audiobook' ? 'audiobook' : sagaFormatOf(series.books),
  title: volume.title,
  authors: series.author ? [series.author] : [],
  ...(volume.date ? { date: volume.date } : {}),
  ...(volume.coverUrl ? { coverUrl: volume.coverUrl } : {}),
  series: { name: series.name, volume: volume.number },
  ...(series.opinion?.rating ? { sagaRating: series.opinion.rating } : {}),
  sagaFavorite: series.opinion?.favorite === true,
  ...(series.language ? { language: series.language } : {}),
})

/** A saga is one kind of object: one volume known as drawn tells for all, the
 *  others most often being a Kindle import that could not tell. */
const sagaFormatOf = (books: readonly Pick<Book, 'format'>[]): BookFormat =>
  books.map(({ format }) => drawnFormatOf(format)).find((format) => format !== undefined) ?? 'book'

/** What an author mostly writes, for a work the web did not say the format of:
 *  a novelist's one comic does not make their next book a comic. */
const authorFormatOf = (books: readonly Pick<Book, 'format'>[]): BookFormat => {
  const counts = new Map<BookFormat, number>()
  for (const { format } of books)
    if (format !== 'audiobook') counts.set(format, (counts.get(format) ?? 0) + 1)
  return [...counts].sort(([, left], [, right]) => right - left)[0]?.[0] ?? 'book'
}

const authorRelease = (row: AuthorDiscovery, format: ReleaseFormat): UpcomingRelease[] => {
  const author = {
    key: row.author.key,
    name: row.author.name,
    favorite: row.author.favorite === true,
    ...(row.author.portraitUrl ? { portraitUrl: row.author.portraitUrl } : {}),
  }
  const works = row.next
    ? [
        {
          id: `author~${row.author.key}~${slugify(row.next.title)}~${format}`,
          source: 'author' as const,
          format:
            format === 'audiobook'
              ? ('audiobook' as const)
              : (row.next.format ?? authorFormatOf(row.author.books)),
          title: row.next.title,
          authors: [row.author.name],
          ...(row.next.date ? { date: row.next.date } : {}),
          ...(row.next.coverUrl ? { coverUrl: row.next.coverUrl } : {}),
          ...(row.next.seriesName
            ? { series: { name: row.next.seriesName, volume: row.next.volume } }
            : {}),
          author,
          sagaFavorite: false,
          ...(row.language ? { language: row.language } : {}),
        },
      ]
    : []
  const awaited = row.awaited.flatMap((view): UpcomingRelease[] =>
    view.state === 'announced' ? [awaitedRelease(view, format)] : [],
  )
  return [...works, ...awaited]
}

const awaitedRelease = (view: AwaitedEditionView, format: ReleaseFormat): UpcomingRelease => ({
  id: `awaited~${view.id}`,
  source: 'awaited',
  format: format === 'audiobook' ? 'audiobook' : (view.source.drawnFormat ?? 'book'),
  title: view.found?.title ?? view.source.title,
  authors: view.source.authors,
  ...(view.found?.date ? { date: view.found.date } : {}),
  ...((view.found?.coverUrl ?? view.source.coverUrl)
    ? { coverUrl: view.found?.coverUrl ?? view.source.coverUrl }
    : {}),
  ...(view.source.series ? { series: view.source.series } : {}),
  sagaFavorite: false,
  language: view.language,
})

/** What is announced across the release watches, one entry per story and
 *  format, the soonest first and the undated last. A story announced both by
 *  its author's watch and by the reader's wait for it is listed once, the saga
 *  winning over the author and the author over the wait. `awaited` holds the
 *  editions the reader still waits for, the ones nothing announced yet
 *  included: they close the list undated. */
export const upcomingOf = (
  discoveries: readonly { format: ReleaseFormat; discovery: Discovery }[],
  narrated: readonly UpcomingRelease[] = [],
  awaited: readonly AwaitedEditionView[] = [],
): UpcomingRelease[] => {
  const all = [
    ...discoveries.flatMap(({ format, discovery }) => [
      ...discovery.sagas.flatMap((row) =>
        row.next ? [sagaRelease(row.series, row.next, format)] : [],
      ),
      ...discovery.authors.flatMap((row) => authorRelease(row, format)),
    ]),
    // After the authors' rows, which already list the waits they announce:
    // what is left are the waits of authors the reader does not hold, and
    // the ones nothing announced yet.
    ...awaited.map((view) => awaitedRelease(view, view.format)),
    // Last, so a recording the sagas, the authors or the reader's own waits
    // already announce is listed as they have it.
    ...narrated,
  ]
  const seen = new Set<string>()
  return all
    .filter((release) => {
      const key = `${release.format}~${slugify(release.title ?? release.id)}`
      if (seen.has(key)) return false
      seen.add(key)
      return true
    })
    .sort(soonestFirst)
}

/** `YYYY`, `YYYY-MM` and `YYYY-MM-DD` compare as text; a year or a month sorts
 *  before the days it contains. */
const soonestFirst = (left: UpcomingRelease, right: UpcomingRelease): number => {
  if (left.date === undefined || right.date === undefined)
    return left.date === right.date ? 0 : left.date === undefined ? 1 : -1
  return left.date < right.date ? -1 : left.date > right.date ? 1 : 0
}

/** What came out since the start of the year, the newest first: the volumes of
 *  the sagas followed, and the awaited editions out in that year. */
export const yearReleasesOf = (
  volumes: readonly { series: FollowedSeries; volume: FoundVolume; format: ReleaseFormat }[],
  awaited: readonly AwaitedEditionView[],
  today: string,
): UpcomingRelease[] =>
  [
    ...volumes.map(({ series, volume, format }) => sagaRelease(series, volume, format)),
    ...awaited
      .filter(
        (view) =>
          view.state === 'available' &&
          view.found?.date !== undefined &&
          view.found.date.length >= 7 &&
          view.found.date.startsWith(today.slice(0, 4)),
      )
      .map((view) => awaitedRelease(view, view.format)),
  ].sort((left, right) => soonestFirst(right, left))

// MARK: - Narrators

/** How long a recording stays news after it came out. */
const NARRATOR_NEWS_DAYS = 30

const dayOf = (date: string): string =>
  date.length === 10 ? date : date.length === 7 ? `${date}-01` : `${date}-01-01`

const daysBefore = (today: string, days: number): string =>
  new Date(Date.parse(`${today}T00:00:00Z`) - days * 86_400_000).toISOString().slice(0, 10)

/** The recordings the narrators the reader follows lent their voice to, that
 *  the reader does not hold: the ones out in the last month are the feed's
 *  news, the ones still to come the calendar's. Dated works only — a
 *  recording with no date is neither news nor a release. `held` holds the shelf
 *  keys of the stories the reader already has. */
export const narratedWorksOf = (
  watches: readonly NarratorWatch[],
  held: ReadonlySet<string>,
  today: string,
): { recent: NarratorNews[]; upcoming: UpcomingRelease[] } => {
  const since = daysBefore(today, NARRATOR_NEWS_DAYS)
  const recent: NarratorNews[] = []
  const upcoming: UpcomingRelease[] = []
  for (const watch of watches)
    for (const work of watch.works) {
      if (!work.date || held.has(shelfKeyOf(work.title, work.authors[0]))) continue
      const day = dayOf(work.date)
      if (day > today)
        upcoming.push({
          id: `narrator~${watch.narratorKey}~${slugify(work.title)}`,
          source: 'narrator',
          format: 'audiobook',
          title: work.title,
          authors: work.authors,
          date: work.date,
          ...(work.coverUrl ? { coverUrl: work.coverUrl } : {}),
          narrator: watch.name,
          sagaFavorite: false,
          language: watch.language,
        })
      else if (day >= since)
        recent.push({
          id: `${watch.narratorKey}~${slugify(work.title)}`,
          narratorKey: watch.narratorKey,
          narrator: watch.name,
          title: work.title,
          authors: work.authors,
          date: work.date,
          ...(work.coverUrl ? { coverUrl: work.coverUrl } : {}),
          language: watch.language,
        })
    }
  return { recent: recent.sort((a, b) => (a.date < b.date ? 1 : -1)), upcoming }
}
