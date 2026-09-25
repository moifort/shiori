import { make } from 'ts-brand'
import { z } from 'zod'
import type { BookFormat } from '~/domain/book/types'
import type {
  ReleaseDate as ReleaseDateType,
  SeriesDescription as SeriesDescriptionType,
  SeriesId as SeriesIdType,
  SeriesName as SeriesNameType,
  VolumeKind,
  VolumeNumber as VolumeNumberType,
} from '~/domain/series/types'
import { VOLUME_KINDS } from '~/domain/series/types'
import { slugify } from '~/utils/slug'

export { AuthorName, BookTitle, Year } from '~/domain/shared/primitives'

export const SeriesId = (value: unknown) => {
  const v = z.string().min(1).max(200).parse(value)
  return make<SeriesIdType>()(v)
}

export const SeriesName = (value: unknown) => {
  const v = z.string().trim().min(1).max(200).parse(value)
  return make<SeriesNameType>()(v)
}

export const SeriesDescription = (value: unknown) => {
  const v = z.string().trim().min(1).max(2000).parse(value)
  return make<SeriesDescriptionType>()(v)
}

// Volume numbers are small positive integers. A saga past 200 volumes is a
// grounding error, not a saga, and a zero or negative number is a misparse of
// "Book 0" prequel notation that belongs in `kind: 'prequel'` instead.
export const VolumeNumber = (value: unknown) => {
  const v = z
    .preprocess((v) => (typeof v === 'string' ? Number(v) : v), z.number().int().min(1).max(200))
    .parse(value)
  return make<VolumeNumberType>()(v)
}

// A year, a month or a day, and a real one: "2027-02-30" is refused rather than
// kept as a date an alert would never reach.
export const ReleaseDate = (value: unknown) => {
  const v = z
    .string()
    .regex(/^\d{4}(-\d{2}(-\d{2})?)?$/, 'a release date is YYYY, YYYY-MM or YYYY-MM-DD')
    .refine((date) => {
      const [year, month = 1, day = 1] = date.split('-').map(Number)
      const parsed = new Date(Date.UTC(year, month - 1, day))
      return parsed.getUTCMonth() === month - 1 && parsed.getUTCDate() === day
    }, 'not a calendar date')
    .parse(value)
  return make<ReleaseDateType>()(v)
}

export const VolumeKindValue = (value: unknown): VolumeKind => z.enum(VOLUME_KINDS).parse(value)

// The catalogue is global and keyed by identity, not by a random id: two readers
// who scan volumes of the same saga must land on the same document, otherwise the
// catalogue is paid for twice and the sharing rule ("books, never series") gets a
// second, divergent copy to reason about.
//
// Diacritics are folded, punctuation dropped, whitespace collapsed, and a leading
// article removed, so "L'Assassin royal" and "Assassin Royal" converge. The author
// is part of the key: series names collide across authors far more often than
// titles do ("Chronicles", "The Saga").
//
// So is the way the saga is taken in. A recording trails its printed book,
// sometimes by years, and some are never made: the saga heard on Audible has a
// spine, a progress and release dates of its own, and is a saga of its own under
// a key ending in `--audio`. Every other format reads the printed saga.
export const seriesKeyOf = (name: string, author: string, format: BookFormat): SeriesIdType =>
  seriesIdFor(SeriesId(`${slugify(name)}--${slugify(author)}`), format)

const AUDIO_SUFFIX = '--audio'

/** Whether a saga is the one heard rather than read. */
export const isAudioSeries = (id: SeriesIdType): boolean => id.endsWith(AUDIO_SUFFIX)

/** The same saga taken in another format: a book whose format changes moves to
 *  the saga of its new format. */
export const seriesIdFor = (id: SeriesIdType, format: BookFormat): SeriesIdType => {
  const read = isAudioSeries(id) ? id.slice(0, -AUDIO_SUFFIX.length) : id
  return SeriesId(format === 'audiobook' ? `${read}${AUDIO_SUFFIX}` : read)
}
