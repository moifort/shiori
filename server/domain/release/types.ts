import type { AudibleAsin } from '~/domain/audible/types'
import type { AwaitedState, FoundEdition } from '~/domain/awaited-edition/types'
import type {
  BookFormat,
  BookLanguage,
  CoverUrl,
  Genre,
  Isbn13,
  ListeningMinutes,
  NarratorName,
  PageCount,
  Publisher,
  Subgenre,
  Synopsis,
} from '~/domain/book/types'
import type { ReleaseDescription, ReleaseFormat, ReleaseSeed } from '~/domain/discovery/types'
import type { ReleaseDate, SeriesId, SeriesName, VolumeNumber } from '~/domain/series/types'
import type { Language } from '~/domain/shared/language'
import type { AuthorName, BookTitle, Year } from '~/domain/shared/types'
import type { ObjectPath } from '~/system/object-store/types'

/** A description of a release, in one language of the app, and the shown
 *  book it was asked for: the original while nobody announced the edition,
 *  the edition once found. A description of the other one is stale. */
export type KeptDescription = {
  description: ReleaseDescription
  describedAt: Date
  /** `describedFromOf(seed)`: which book the description describes. */
  describedFrom: string
}

/** One book in one format and one language — a translation, a recording, a
 *  saga's volume — as the web found it and its page described it. Shared by
 *  every reader, holding no reference to anybody, keyed on the book: every
 *  list and every page that shows it reads this one document, so the grounded
 *  calls behind it are paid once.
 *
 *  An edition looked for on the web (`checkedAt`) is the watch an awaited
 *  edition, an award winner or a discovery reads where it stands; a release
 *  only described — a winner nobody awaited, a saga's volume, whose found
 *  facts are its saga's watch — has no `checkedAt`. */
export type Release = {
  /** `{shelfKey}--{format}--{language}`: see `releaseKeyOf`. */
  key: string
  /** The book it is looked for from: the original, or the volume. */
  title: BookTitle
  author?: AuthorName
  originalLanguage: BookLanguage
  series?: { name: SeriesName; volume?: VolumeNumber }
  format: ReleaseFormat
  /** The language of the edition. */
  language: BookLanguage
  /** When the web was last searched for it. Absent on a release never looked
   *  for on its own. */
  checkedAt?: Date
  found?: FoundEdition
  /** Its page's description, in each language of the app it was asked in. */
  descriptions?: Partial<Record<Language, KeptDescription>>
}

/** A release as one reader is shown it, in a list and on its page alike: what
 *  the app knows of it — the seed — completed by its description. Built once,
 *  on the server, by `releaseViewOf`; nothing is merged on a phone. */
export type ReleaseView = {
  key: string
  title: BookTitle
  originalTitle: BookTitle
  authors: AuthorName[]
  /** What the book is: a novel, a manga, a recording. */
  format: BookFormat
  releaseFormat: ReleaseFormat
  /** The language of the book shown: the original's while nobody announced
   *  the edition, the edition's once found. */
  language: BookLanguage
  /** The language of the edition looked for: whose store sells it. */
  editionLanguage: BookLanguage
  originalLanguage: BookLanguage
  state: AwaitedState
  /** Whether the web was ever searched for it. */
  watched: boolean
  date?: ReleaseDate
  isbn13?: Isbn13
  asin?: AudibleAsin
  /** The edition's cover once found, else the shown book's. */
  coverUrl?: CoverUrl
  /** The reader's own photo of the book it is awaited from, signed when drawn. */
  coverPath?: ObjectPath
  /** The cover its description found, drawn when there is no other. */
  describedCoverUrl?: CoverUrl
  /** A cover found elsewhere, a catalogue's, drawn last. */
  fallbackCoverUrl?: CoverUrl
  series?: { seriesId?: SeriesId; name: SeriesName; volume?: VolumeNumber }
  publisher?: Publisher
  firstPublishedIn?: Year
  synopsis?: Synopsis
  genre?: Genre
  subgenres: Subgenre[]
  pageCount?: PageCount
  narrators: NarratorName[]
  durationMinutes?: ListeningMinutes
  /** Whether a description that serves as it is was kept: when false, opening
   *  its page describes it. */
  described: boolean
  /** The edition as the web found it: what its store link is made of. */
  found?: FoundEdition
}

/** What the server knows of a release before its description, and how it was
 *  found: everything `releaseViewOf` completes. Each kind of item — an awaited
 *  edition, an award winner, a discovery, a saga's volume — says it its way. */
export type ReleaseShown = {
  key: string
  seed: ReleaseSeed
  originalTitle: BookTitle
  originalLanguage: BookLanguage
  language: BookLanguage
  releaseFormat: ReleaseFormat
  state: AwaitedState
  watched: boolean
  found?: FoundEdition
  coverPath?: ObjectPath
  /** A cover found elsewhere, a catalogue's, drawn after its description's. */
  fallbackCoverUrl?: CoverUrl
  series?: { seriesId?: SeriesId; name: SeriesName; volume?: VolumeNumber }
}

/** The book a release is of, written beside its description when the release
 *  held nothing yet. */
export type ReleaseIdentity = Omit<Release, 'descriptions' | 'checkedAt' | 'found'>
