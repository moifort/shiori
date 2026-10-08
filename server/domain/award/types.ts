import type { AwaitedEditionId, AwaitedState, EditionWatch } from '~/domain/awaited-edition/types'
import type { BookLanguage, Genre } from '~/domain/book/types'
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
] as const
export type Award = (typeof AWARDS)[number]

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
  /** The language it won in: English for every award listed. */
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
  /** Whether the reader may await its edition from the row: not out, not
   *  awaited already, and a format the edition can be awaited in. */
  awaitable: boolean
  /** The edition the reader awaits already, when they do. */
  awaitedId?: AwaitedEditionId
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

/** That somebody looked at a genre's winners in a language: what the hourly
 *  pass watches. Shared, keyed `{genre}--{language}`, naming nobody. */
export type AwardInterest = {
  key: string
  genre: Genre
  language: BookLanguage
  requestedAt: Date
}
