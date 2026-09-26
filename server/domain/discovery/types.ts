import type { AudibleAsin } from '~/domain/audible/types'
import type { BookLanguage, CoverUrl, Isbn13 } from '~/domain/book/types'
import type { ReleaseDate, SeriesId, SeriesName, VolumeNumber } from '~/domain/series/types'
import type { FollowedSeries } from '~/domain/series/use-case'
import type { Language } from '~/domain/shared/language'
import type { AuthorName, BookTitle, UserId } from '~/domain/shared/types'

export type { ReleaseDate } from '~/domain/series/types'

/** The two ways a saga reaches a reader: printed or electronic, and recorded.
 *  Read off the saga's id — a saga heard is its own saga. */
export type ReleaseFormat = 'book' | 'audiobook'

/** A saga in the language one reader follows it in: what the web is searched
 *  for, and the key the shared watch is stored under. */
export type WatchedSaga = {
  seriesId: SeriesId
  language: BookLanguage
  /** The saga's name and author as the reader's books give them: what the web
   *  is searched with. */
  name: SeriesName
  author?: AuthorName
}

/** One volume of a saga as the web found it in one language, out or announced. */
export type FoundVolume = {
  number: VolumeNumber
  title: BookTitle
  /** When it came out or comes out, as precisely as announced. Absent for a
   *  volume out on a date nobody found. */
  date?: ReleaseDate
  isbn13?: Isbn13
  /** The recording on Audible, kept only once Audible's own catalogue answered
   *  for it: a model's ASIN is never trusted as it is. */
  asin?: AudibleAsin
  /** The publisher's cover, found by the ISBN. */
  coverUrl?: CoverUrl
}

/** What exists or is announced of one saga in one language, as the web says —
 *  shared by every reader who follows it, keyed on the saga rather than on
 *  anybody, so the grounded call behind it is paid once a week. */
export type SagaWatch = {
  /** `{seriesId}--{language}`. */
  key: string
  seriesId: SeriesId
  name: SeriesName
  author?: AuthorName
  language: BookLanguage
  checkedAt: Date
  /** Numbered volumes, in order, in the saga's own format. */
  volumes: FoundVolume[]
}

/** What the hourly pass knows of one reader, so it reads their library once a
 *  day rather than every hour: the sagas they follow, and the alerts already
 *  pushed to them. */
export type DiscoveryReader = {
  userId: UserId
  /** The app's language, as the reader's last look at the tab said, since the
   *  scheduled passes have no request: what alerts are written in. */
  language: Language
  sagas: WatchedSaga[]
  /** When `sagas` was last worked out from the library. */
  syncedAt: Date
  /** `{watchKey}--{volume}`: an alert goes out once. */
  notified: string[]
}

/** Where the reader goes to get a volume: a bookshop for a printed saga, the
 *  recording's own page — or a search — on Audible for a saga heard. */
export type Store = 'amazon' | 'audible'

/** A volume as the reader is offered it. */
export type OfferedVolume = FoundVolume & { store: Store; storeUrl: string }

/** What one saga has for the reader: the volumes out they do not hold, and the
 *  next one announced. */
export type SagaReleases = {
  available: OfferedVolume[]
  next?: OfferedVolume
}

/** One row of the Découvrir tab. */
export type SagaDiscovery = SagaReleases & { series: FollowedSeries }
