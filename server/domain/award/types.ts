import type { AwaitedEditionId, AwaitedState, EditionWatch } from '~/domain/awaited-edition/types'
import type { BookLanguage, CoverUrl, Genre } from '~/domain/book/types'
import type { ReleaseFormat } from '~/domain/discovery/types'
import type { AuthorName, BookTitle } from '~/domain/shared/types'

/** The awards Découvrir lists the winners of: novel categories only. */
export const AWARDS = [
  'hugo',
  'nebula',
  'locus-sf',
  'locus-fantasy',
  'clarke',
  'world-fantasy',
  'goncourt',
] as const
export type Award = (typeof AWARDS)[number]

/** What an award crowns, for a card that names the prize and its category. */
export type AwardCategory = 'novel' | 'science-fiction-novel' | 'fantasy-novel'

/** One prize a work won, and the year it was presented. */
export type AwardMention = { award: Award; year: number }

/** A novel that won at least one of the awards, once however many it won: the
 *  Hugo and the Nebula of the same year are one row with two mentions. Shared
 *  by every reader, holding nothing of anybody. */
export type AwardedWork = {
  /** `shelfKeyOf(title, first author)`: how the work is told from another. */
  key: string
  title: BookTitle
  authors: AuthorName[]
  /** The language it won in: the award's — see `AWARD_LANGUAGES`. */
  language: BookLanguage
  /** Newest first. */
  mentions: AwardMention[]
}

/** A genre's winners as one reader sees them in one format and the app's
 *  language: where the edition stands, as the shared watch says. */
export type AwardedWorkView = {
  work: AwardedWork
  format: ReleaseFormat
  language: BookLanguage
  watchKey: string
  watch?: EditionWatch
  state: AwaitedState
  /** Whether the reader may await its edition from the row in the format
   *  shown: `awaitableFormats` holds it. Kept for the builds that ask it. */
  awaitable: boolean
  /** The formats the reader may await its edition in from its page, whatever
   *  the format shown: the ones the edition can be awaited in — see
   *  `awaitableFormatsOf` — not out and not awaited already in that format. */
  awaitableFormats: ReleaseFormat[]
  /** The edition the reader awaits already, when they do. */
  awaitedId?: AwaitedEditionId
  /** The cover its page found when it was opened and described, drawn until
   *  the watch finds the edition's own. */
  describedCoverUrl?: CoverUrl
}

/** One award's winners on the full list: the ones the reader does not hold, and
 *  how many of all its winners they read. */
export type AwardList = {
  award: Award
  winners: AwardedWorkView[]
  readCount: number
  total: number
}

/** What Découvrir shows of the awards: the reader's genre, the other genres
 *  they could switch to, the latest winners they do not hold, and every award
 *  of the genre in full. */
export type AwardShelf = {
  genre: Genre
  genres: Genre[]
  recent: AwardedWorkView[]
  awards: AwardList[]
}

/** One genre's section on Découvrir: the latest winners of its awards the
 *  reader does not hold, none of them drawn in another section. */
export type AwardSection = {
  genre: Genre
  winners: AwardedWorkView[]
}

/** One year of an award as the daily pass found it on Wikidata, after the
 *  ceremony: the years the versioned list does not hold yet. Shared, keyed
 *  `{award}~{year}`, naming nobody. */
export type FoundWinners = {
  key: string
  award: Award
  year: number
  winners: { title: string; authors: string[] }[]
  foundAt: Date
}
