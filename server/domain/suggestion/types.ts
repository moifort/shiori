import type { AwaitedEditionId, AwaitedState, EditionWatch } from '~/domain/awaited-edition/types'
import type { BookId, BookLanguage, CoverUrl, Genre, StarRating } from '~/domain/book/types'
import type { ReleaseFormat } from '~/domain/discovery/types'
import type { SeriesId } from '~/domain/series/types'
import type { Language } from '~/domain/shared/language'
import type { AuthorName, BookTitle, UserId } from '~/domain/shared/types'

/** What a suggested book is, as the model names it. */
export const SUGGESTION_KINDS = ['novel', 'essay', 'comic', 'manga'] as const
export type SuggestionKind = (typeof SUGGESTION_KINDS)[number]

/** A book the model thinks the reader would love, with why: the reason it
 *  gave, the "comme …" line under its cover, and the reader's own books it
 *  drew on. Private to the reader it was chosen for. */
export type Suggestion = {
  /** `shelfKeyOf(originalTitle, first author)`: how a suggestion is told from
   *  another, and from a book the reader holds. */
  key: string
  /** The title the model gave in the app's language. A guess for a recent
   *  translation: the page's description gives the edition's real one. */
  title: BookTitle
  originalTitle: BookTitle
  authors: AuthorName[]
  /** The language the book was written in. */
  language: BookLanguage
  kind: SuggestionKind
  /** One sentence, citing a book of the reader's. */
  reason: string
  /** Two or three words for under its cover: "comme Gagner la guerre". */
  short: string
  /** The titles of the reader's books the reason draws on, as the model wrote
   *  them; matched back to the library when shown. */
  references: string[]
  /** The cover a catalogue found when the suggestion was checked. */
  coverUrl?: CoverUrl
}

/** The reader's suggestions of the month: the selection the line draws its
 *  covers from, the month it was chosen for, and when the model was last asked —
 *  never twice in a day. One document per reader. */
export type SuggestionQueue = {
  userId: UserId
  /** `YYYY-MM`: the month the line is titled after. */
  month: string
  /** The app's language the reasons were written in: a reader who changes it
   *  is given a selection in the new one. */
  language: Language
  generatedAt: Date
  /** Set while the model is being asked, so a second look — Découvrir's view
   *  asks again as it settles — knows a selection is on its way rather than
   *  taking the month for one with none. */
  generatingSince?: Date
  /** In the order the model ranked them, checked against the library and the
   *  catalogues when they were kept. */
  suggestions: Suggestion[]
}

/** Why the reader turned a suggestion down: "Pas intéressé" — not for now,
 *  says little of their taste — or "Je n'aime pas" — not their kind of book,
 *  which the model reads as a disappointment. */
export const DISMISSAL_REASONS = ['not-interested', 'disliked'] as const
export type DismissalReason = (typeof DISMISSAL_REASONS)[number]

/** A suggestion the reader turned down: never suggested again, and the latest
 *  ones told to the model with why. */
export type Dismissal = {
  userId: UserId
  key: string
  title: BookTitle
  authors: AuthorName[]
  /** Absent on the dismissals saved before the reason was asked: each was a
   *  "Pas intéressé". */
  reason?: DismissalReason
  dismissedAt: Date
}

/** How a reference book ranks for the reader: its own heart or stars, or its
 *  saga's when it has none of its own. */
export type ReferenceRank = { favorite: boolean; rating?: StarRating; viaSeries: boolean }

/** One of the reader's books a suggestion was drawn from. */
export type SuggestionReference = {
  bookId: BookId
  /** The edition of the saga cited. A reference stored before the edition ids
   *  holds the bare saga key, which the saga page still opens. */
  seriesId?: SeriesId
  /** The saga's name when the reference is a saga, else the book's title. */
  title: string
  /** The reason cites the saga by name rather than one of its books: the
   *  reference opens the saga's page, not its first volume's. */
  citesSaga: boolean
  rank: ReferenceRank
  /** The book's genre — a saga's, its first volume that has one — which the
   *  app draws as the reference's symbol. */
  genre?: Genre
  /** The reader's own cover of the book, signed when it is their photo. */
  coverUrl?: string
}

/** A suggestion as one reader sees it in one format and the app's language:
 *  its reason, its references matched to the library, and where its edition
 *  stands, as the shared watch says. */
export type SuggestionView = {
  suggestion: Suggestion
  format: ReleaseFormat
  language: BookLanguage
  watchKey: string
  watch?: EditionWatch
  state: AwaitedState
  awaitableFormats: ReleaseFormat[]
  awaitedId?: AwaitedEditionId
  describedCoverUrl?: CoverUrl
  references: SuggestionReference[]
}

/** Where the month's selection stands: made — its suggestions may have run
 *  out — being made, or not made at all: never asked for this month, failed,
 *  or no model key. */
export const DISCOVERIES_STATUSES = ['ready', 'searching', 'none'] as const
export type DiscoveriesStatus = (typeof DISCOVERIES_STATUSES)[number]

/** The line Découvrir and the home page draw: the month it is titled after
 *  and every suggestion of the month's selection still to show. */
export type MonthlyDiscoveries = {
  month: string
  status: DiscoveriesStatus
  suggestions: SuggestionView[]
}
