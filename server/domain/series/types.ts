import type { Brand } from 'ts-brand'
import type { BookLanguage, CoverUrl } from '~/domain/book/types'
import type { AuthorName, BookTitle, Year } from '~/domain/shared/types'

export type SeriesId = Brand<string, 'SeriesId'>
export type SeriesName = Brand<string, 'SeriesName'>
export type SeriesDescription = Brand<string, 'SeriesDescription'>
export type VolumeNumber = Brand<number, 'VolumeNumber'>

/** When a book comes out, as precisely as anybody announced it: a year, a
 *  month, or a day. */
export type ReleaseDate = Brand<string, 'ReleaseDate'>

/** Where a volume sits in a saga. A `main` volume belongs to the reading spine and
 *  carries a number; everything else orbits it and often has none, which is why
 *  `Volume.number` is optional. Classifying before describing is what makes the
 *  model's catalogue output usable. */
export const VOLUME_KINDS = ['main', 'prequel', 'spin-off', 'novella', 'companion'] as const
export type VolumeKind = (typeof VOLUME_KINDS)[number]

export type Volume = {
  number?: VolumeNumber
  title: BookTitle
  publishedIn?: Year
  kind: VolumeKind
  /** When this volume came out, or comes out, in each language the release
   *  watch found it in — as precisely as it was announced. Written by the
   *  watch, never by a reader: an edition language decides whether the volume
   *  is out for the reader holding that edition. */
  releases?: Partial<Record<BookLanguage, ReleaseDate>>
  /** Its title in those languages, when it differs from `title`. */
  titles?: Partial<Record<BookLanguage, BookTitle>>
  /** The publisher's cover of that edition, found by its ISBN. */
  covers?: Partial<Record<BookLanguage, CoverUrl>>
}

/** The public catalogue of a saga. It holds no reference to any user: it is a
 *  fact about the world, written once and read by everyone, which is what lets a
 *  single AI call serve every reader of the saga. It is never exposed through
 *  library sharing. */
export type Series = {
  id: SeriesId
  name: SeriesName
  author: AuthorName
  description?: SeriesDescription
  /** Publication order, which is verifiable. Reading order differs on many sagas
   *  and is an opinion the model restitutes inconsistently. */
  volumes: Volume[]
  catalogedAt: Date
  /** Drawn on the fly from a reader's own count of the volumes, for a saga
   *  nobody has catalogued: their volumes at their numbers, the saga's name
   *  standing in for the rest. Never stored — the shared catalogue holds what
   *  the world says, and a guess typed by one reader is not that. */
  provisional?: true
}

/** A saga the catalogue call answered with no volume at all — a saga heard that
 *  Audible lists no recording of, most often. Remembered so that the next
 *  opening does not wait on the same grounded call, and forgotten after a while
 *  so that a recording published since is found. */
export type SeriesMiss = {
  id: SeriesId
  missedAt: Date
}

/** Where the reader stands on a saga: not started, working through it, done
 *  with it, or set aside. Derived, never stored: it depends on which books the
 *  reader owns — and, for `unfollowed`, on their own choice to stop following
 *  it, which overrides the rest. */
export type SeriesState = 'not-started' | 'in-progress' | 'complete' | 'unfollowed'
