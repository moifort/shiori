import type { Brand } from 'ts-brand'
import type { AudibleAsin } from '~/domain/audible/types'
import type { BookId, BookLanguage, CoverUrl, Isbn13 } from '~/domain/book/types'
import type { ReleaseFormat } from '~/domain/discovery/types'
import type { ReleaseDate, SeriesName, VolumeNumber } from '~/domain/series/types'
import type { AuthorName, BookTitle, UserId } from '~/domain/shared/types'
import type { ObjectPath } from '~/system/object-store/types'

/** `{userId}--{watchKey}`: a reader awaits one book in one format once. */
export type AwaitedEditionId = Brand<string, 'AwaitedEditionId'>

/** The book an edition is awaited of, as its page showed it: the reader's own
 *  copy or a friend's, in a language other than the app's. */
export type AwaitedSource = {
  bookId: BookId
  /** Whose book it is: the reader, or the friend it was seen at. */
  ownerId: UserId
  title: BookTitle
  authors: AuthorName[]
  language: BookLanguage
  series?: { name: SeriesName; volume?: VolumeNumber }
  /** The publisher's cover, drawn until the edition awaited has its own. */
  coverUrl?: CoverUrl
  /** The reader's own photo of their copy, signed when drawn. Never a friend's:
   *  it lives under their account. */
  coverPath?: ObjectPath
}

/** A book a reader waits to see come out in the app's language, in one format:
 *  translated into print, or recorded. Private, one document per book and
 *  format, owned by exactly one reader. The web is searched for it through a
 *  shared `EditionWatch`. */
export type AwaitedEdition = {
  id: AwaitedEditionId
  userId: UserId
  format: ReleaseFormat
  /** The language the edition is awaited in: the app's when it was asked for. */
  language: BookLanguage
  source: AwaitedSource
  watchKey: string
  awaitedAt: Date
  /** When the alert for its release went out, or was passed over because the
   *  edition was already out when the reader asked for it. */
  notifiedAt?: Date
}

/** The edition awaited, as the web found it and a store confirmed it. */
export type FoundEdition = {
  title: BookTitle
  /** When it came out or comes out, as precisely as announced. */
  date?: ReleaseDate
  /** The printed edition, kept only once Amazon knows it in that language. */
  isbn13?: Isbn13
  /** The recording, kept only once Audible's own catalogue answered for it. */
  asin?: AudibleAsin
  coverUrl?: CoverUrl
}

/** What the web says of one book in one language and format — shared by every
 *  reader who awaits it, keyed on the book rather than on anybody, so the
 *  grounded call behind it is paid once a week. */
export type EditionWatch = {
  /** `{shelfKey}--{format}--{language}`. */
  key: string
  title: BookTitle
  author?: AuthorName
  originalLanguage: BookLanguage
  series?: { name: SeriesName; volume?: VolumeNumber }
  format: ReleaseFormat
  language: BookLanguage
  checkedAt: Date
  found?: FoundEdition
}

/** Where an awaited edition stands: nothing found yet, found but not out, or
 *  out — for a recording, only once Audible confirmed it. */
export type AwaitedState = 'unannounced' | 'announced' | 'available'

/** An awaited edition as the app draws it. */
export type AwaitedEditionView = AwaitedEdition & {
  state: AwaitedState
  found?: FoundEdition
  /** Whether the web was ever searched for it. */
  watched: boolean
}

/** What a book's page offers: the formats its edition in the app's language
 *  may be awaited in, and the ones already awaited. */
export type EditionOffer = {
  formats: ReleaseFormat[]
  awaited: AwaitedEditionView[]
}
