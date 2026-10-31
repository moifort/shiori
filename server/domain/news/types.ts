import type { SharedFavorite } from '~/domain/analytics/types'
import type { AuthorKey, PortraitUrl } from '~/domain/author/types'
import type { BookFormat, CoverUrl, NarratorName } from '~/domain/book/types'
import type { NarratorKey } from '~/domain/narrator/types'
import type { ReleaseDate, SeriesName, VolumeNumber } from '~/domain/series/types'
import type { AuthorName, BookTitle, StarRating, UserId } from '~/domain/shared/types'

/** What a friend did to a book that is worth telling the others: picked it up,
 *  finished it, or loved it. Shelving and dropping are left out of the feed —
 *  they are bookkeeping, not news. */
export type FeedEventKind = 'started' | 'finished' | 'loved'

/** One thing a friend did, as the feed draws a row. Derived per request from
 *  the friends' shared shelves, never stored. */
export type FeedEvent = {
  /** `{userId}~{kind}~{bookId}`: stable, and the tie-break of the cursor. */
  id: string
  kind: FeedEventKind
  at: Date
  friend: { userId: UserId; firstName?: string }
  book: SharedFavorite
  /** Their stars, on a finish or a heart that carries them. */
  rating?: StarRating
  /** How many of the reader's other friends picked up the same story lately:
   *  "Comme 3 de vos amis". Zero outside a start. */
  alsoStartedBy: number
  /** Whether the reader already holds the story, on any shelf. */
  inLibrary: boolean
}

export type FeedPage = {
  events: FeedEvent[]
  /** The cursor of the next page; absent on the last one. */
  nextCursor?: string
}

/** Where an upcoming release comes from among the things the reader follows. */
export type ReleaseSource = 'saga' | 'author' | 'awaited' | 'narrator'

/** One book announced, as the calendar and the feed's author card draw it.
 *  Merged from what the existing release watches already hold: a saga's next
 *  volume, an author's next work, an edition the reader awaits. */
export type UpcomingRelease = {
  /** Stable for a story and a format. */
  id: string
  source: ReleaseSource
  format: BookFormat
  /** Absent on an announcement that names no title yet. */
  title?: BookTitle
  authors: AuthorName[]
  /** As precisely as announced: `YYYY`, `YYYY-MM` or `YYYY-MM-DD`. Absent on a
   *  release announced for a date nobody found. */
  date?: ReleaseDate
  coverUrl?: CoverUrl
  series?: { name: SeriesName; volume?: VolumeNumber }
  /** The author it comes from, for a work of an author the reader follows. */
  author?: { key: AuthorKey; name: AuthorName; favorite: boolean; portraitUrl?: PortraitUrl }
  /** The reader's stars for the saga, when it is a saga's volume. */
  sagaRating?: StarRating
  sagaFavorite: boolean
  /** The narrator who lends their voice, on a recording they were found for. */
  narrator?: NarratorName
}

/** A narrator the reader follows lending their voice to a recording out
 *  lately: the feed's "prête sa voix à". Derived per request from the shared
 *  narrator watches, never stored. */
export type NarratorNews = {
  id: string
  narratorKey: NarratorKey
  narrator: NarratorName
  title: BookTitle
  authors: AuthorName[]
  date: ReleaseDate
  coverUrl?: CoverUrl
}
