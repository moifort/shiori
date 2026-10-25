import { make } from 'ts-brand'
import { z } from 'zod'
import { BOOK_LANGUAGES, type BookFormat, type BookLanguage } from '~/domain/book/types'
import type {
  ReleaseDate as ReleaseDateType,
  SagaKey as SagaKeyType,
  SeriesDescription as SeriesDescriptionType,
  SeriesId as SeriesIdType,
  SeriesName as SeriesNameType,
  VolumeKind,
  VolumeNumber as VolumeNumberType,
} from '~/domain/series/types'
import { VOLUME_KINDS } from '~/domain/series/types'
import { singleSpaced } from '~/domain/shared/primitives'
import { slugify } from '~/utils/slug'

export { AuthorName, BookTitle, Year } from '~/domain/shared/primitives'

export const SagaKey = (value: unknown) => {
  const v = z.string().min(1).max(200).parse(value)
  return make<SagaKeyType>()(v)
}

/** A series id as a client sends it: an edition's, or — from a build older
 *  than the edition ids — a bare saga key, which the API still accepts. */
export const SeriesId = (value: unknown) => {
  const v = z.string().min(1).max(200).parse(value)
  return make<SeriesIdType>()(v)
}

export const SeriesName = (value: unknown) => {
  const v = z.string().transform(singleSpaced).pipe(z.string().min(1).max(200)).parse(value)
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
export const seriesKeyOf = (name: string, author: string, format: BookFormat): SagaKeyType =>
  sagaKeyFor(SagaKey(`${slugify(name)}--${slugify(author)}`), format)

/** The same saga keyed with its author's names in the other order: "Garon
 *  Tsuchiya" and "Tsuchiya Garon" are one author, family name first or last
 *  as the edition prints it, and a scan of each would otherwise start a saga
 *  and pay for a catalogue of its own. Undefined when the order changes
 *  nothing — a single name. The key itself stays as it was: every stored id
 *  would have to move for a case this rare, so the readers of the key look
 *  this one up beside it. */
export const keyWithAuthorReversed = (id: SagaKeyType): SagaKeyType | undefined => {
  const heard = isAudioSeries(id)
  const read = heard ? id.slice(0, -AUDIO_SUFFIX.length) : id
  const [name, author] = read.split('--')
  if (!name || !author) return undefined
  const reversed = author.split('-').reverse().join('-')
  if (reversed === author) return undefined
  return SagaKey(`${name}--${reversed}${heard ? AUDIO_SUFFIX : ''}`)
}

/** The id of a saga's edition in one language: the saga's key, then the
 *  language after a `~` no slug can produce. Built when something is written —
 *  a book, a catalogue — and stored there; a reader of the data takes the id
 *  it finds rather than building it again. The volumes that record no
 *  language, which no longer exist, would keep the bare key. */
export const seriesIdOf = (saga: SagaKeyType, language?: BookLanguage): SeriesIdType =>
  make<SeriesIdType>()(language ? `${saga}~${language}` : saga)

/** What a series id sent by a client names: one edition of a saga, or — a bare
 *  key, from a build older than the edition ids — the saga alone, its edition
 *  left to the `language` argument that build sends beside it.
 *
 *  The one place an id is split, at the API's door: it has to tell the two
 *  forms apart anyway, and the `~` cannot come out of a slug. Inside, the saga
 *  is read from the `saga` field stored beside every id. */
export const seriesReferenceOf = (
  id: SeriesIdType,
  language?: BookLanguage,
): { saga: SagaKeyType; language?: BookLanguage; edition: boolean } => {
  const at = id.lastIndexOf('~')
  const named = at < 0 ? undefined : id.slice(at + 1)
  if (at < 0 || !(BOOK_LANGUAGES as readonly string[]).includes(named ?? ''))
    return { saga: SagaKey(id), ...(language ? { language } : {}), edition: false }
  return { saga: SagaKey(id.slice(0, at)), language: named as BookLanguage, edition: true }
}

const AUDIO_SUFFIX = '--audio'

/** Whether a saga is the one heard rather than read. */
export const isAudioSeries = (id: SagaKeyType): boolean => id.endsWith(AUDIO_SUFFIX)

/** The same saga taken in another format: a book whose format changes moves to
 *  the saga of its new format. */
export const sagaKeyFor = (id: SagaKeyType, format: BookFormat): SagaKeyType => {
  const read = isAudioSeries(id) ? id.slice(0, -AUDIO_SUFFIX.length) : id
  return SagaKey(format === 'audiobook' ? `${read}${AUDIO_SUFFIX}` : read)
}
