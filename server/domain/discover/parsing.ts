import { shelfKeyOf } from '~/domain/book/business-rules'
import { BookLanguageValue, GenreValue, Isbn13, Synopsis } from '~/domain/book/primitives'
import { SeriesName, VolumeNumber } from '~/domain/series/primitives'
import { AuthorName, BookTitle, Year } from '~/domain/shared/primitives'
import { isPresent, optionally } from '~/utils/input'
import { ReleaseDate } from './primitives'
import type { ReleasesOutput, SuggestionOutput } from './schemas'
import type { Suggestion, WatchedRelease } from './types'

/** The most a reason may run to: one line on a phone, a little more on the
 *  suggestion page. A model that writes a paragraph is cut, not refused. */
const REASON_MAX = 240
const AWARD_MAX = 60

const authorsOf = (values: readonly unknown[] | undefined) =>
  (values ?? [])
    .map((value) => optionally(value, AuthorName))
    .filter(isPresent)
    .slice(0, 5)

const trimmed = (value: unknown, max: number): string | undefined =>
  typeof value === 'string' && value.trim() !== '' ? value.trim().slice(0, max) : undefined

/** One suggestion out of a model's answer, or nothing when it names no book.
 *  Every other field is dropped on its own when it does not validate: a
 *  hallucinated ISBN must not cost the reader a good suggestion. */
export const suggestionFrom = (raw: SuggestionOutput): Suggestion | undefined => {
  const title = optionally(raw.title, BookTitle)
  const reason = trimmed(raw.reason, REASON_MAX)
  if (!title || !reason) return undefined
  const authors = authorsOf(raw.authors)
  const seriesName = optionally(raw.seriesName, SeriesName)
  const rating =
    typeof raw.publicRating === 'number' && raw.publicRating > 0 && raw.publicRating <= 5
      ? Math.round(raw.publicRating * 10) / 10
      : undefined
  const count =
    typeof raw.ratingCount === 'number' && raw.ratingCount > 0
      ? Math.round(raw.ratingCount)
      : undefined
  return {
    key: shelfKeyOf(title, authors[0]),
    title,
    authors,
    firstPublishedIn: optionally(raw.year, Year),
    language: optionally(raw.language, BookLanguageValue),
    format: 'book',
    genre: optionally(raw.genre, GenreValue),
    series: seriesName
      ? { name: seriesName, volume: optionally(raw.volume, VolumeNumber) }
      : undefined,
    synopsis: optionally(raw.synopsis, Synopsis),
    isbn13: optionally(raw.isbn13, Isbn13),
    reason,
    award: trimmed(raw.award, AWARD_MAX),
    publicRating: rating,
    ratingCount: rating === undefined ? undefined : count,
  }
}

export const suggestionsFrom = (raws: readonly SuggestionOutput[] | undefined): Suggestion[] =>
  (raws ?? []).map(suggestionFrom).filter(isPresent)

type RawRelease = NonNullable<NonNullable<ReleasesOutput['subjects']>[number]['releases']>[number]

/** One announced release, or nothing without a title and a real date. */
export const watchedReleaseFrom = (raw: RawRelease): WatchedRelease | undefined => {
  const title = optionally(raw.title, BookTitle)
  const date = optionally(raw.date, ReleaseDate)
  if (!title || !date) return undefined
  return {
    title,
    authors: authorsOf(raw.authors),
    volume: optionally(raw.volume, VolumeNumber),
    date,
    format: raw.format === 'audiobook' ? 'audiobook' : 'book',
    language: optionally(raw.language, BookLanguageValue),
    isbn13: optionally(raw.isbn13, Isbn13),
  }
}
