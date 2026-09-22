import type { Brand } from 'ts-brand'
import type { AuthorName, BookTitle, Year } from '~/domain/shared/types'

export type SeriesId = Brand<string, 'SeriesId'>
export type SeriesName = Brand<string, 'SeriesName'>
export type SeriesDescription = Brand<string, 'SeriesDescription'>
export type VolumeNumber = Brand<number, 'VolumeNumber'>

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

/** Where the reader stands on a saga: not started, working through it, or done
 *  with it. Derived, never stored: it depends on which books the reader owns. */
export type SeriesState = 'not-started' | 'in-progress' | 'complete'
